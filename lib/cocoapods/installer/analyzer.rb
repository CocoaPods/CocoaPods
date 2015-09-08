module Pod
  class Installer
    # Analyzes the Podfile, the Lockfile, and the sandbox manifest to generate
    # the information relative to a CocoaPods installation.
    #
    class Analyzer
      include Config::Mixin

      autoload :AnalysisResult,            'cocoapods/installer/analyzer/analysis_result'
      autoload :SandboxAnalyzer,           'cocoapods/installer/analyzer/sandbox_analyzer'
      autoload :SpecsState,                'cocoapods/installer/analyzer/specs_state'
      autoload :LockingDependencyAnalyzer, 'cocoapods/installer/analyzer/locking_dependency_analyzer'
      autoload :TargetInspectionResult,    'cocoapods/installer/analyzer/target_inspection_result'
      autoload :TargetInspector,           'cocoapods/installer/analyzer/target_inspector'

      # @return [Sandbox] The sandbox where the Pods should be installed.
      #
      attr_reader :sandbox

      # @return [Podfile] The Podfile specification that contains the
      #         information of the Pods that should be installed.
      #
      attr_reader :podfile

      # @return [Lockfile] The Lockfile that stores the information about the
      #         Pods previously installed on any machine.
      #
      attr_reader :lockfile

      # Initialize a new instance
      #
      # @param  [Sandbox]  sandbox     @see sandbox
      # @param  [Podfile]  podfile     @see podfile
      # @param  [Lockfile] lockfile    @see lockfile
      #
      def initialize(sandbox, podfile, lockfile = nil)
        @sandbox  = sandbox
        @podfile  = podfile
        @lockfile = lockfile

        @update = false
        @allow_pre_downloads = true
      end

      # Performs the analysis.
      #
      # The Podfile and the Lockfile provide the information necessary to
      # compute which specification should be installed. The manifest of the
      # sandbox returns which specifications are installed.
      #
      # @param  [Bool] allow_fetches
      #         whether external sources may be fetched
      #
      # @return [AnalysisResult]
      #
      def analyze(allow_fetches = true)
        validate_podfile!
        validate_lockfile_version!
        @result = AnalysisResult.new
        if config.integrate_targets?
          @result.target_inspections = inspect_targets_to_integrate
        else
          verify_platforms_specified!
        end
        @result.podfile_state = generate_podfile_state
        @locked_dependencies  = generate_version_locking_dependencies

        store_existing_checkout_options
        fetch_external_sources if allow_fetches
        @result.specs_by_target = validate_platforms(resolve_dependencies)
        @result.specifications  = generate_specifications
        @result.targets         = generate_targets
        @result.sandbox_state   = generate_sandbox_state
        @result
      end

      attr_accessor :result

      # @return [Bool] Whether an installation should be performed or this
      #         CocoaPods project is already up to date.
      #
      def needs_install?
        analysis_result = analyze(false)
        podfile_needs_install?(analysis_result) || sandbox_needs_install?(analysis_result)
      end

      # @param  [AnalysisResult] analysis_result
      #         the analysis result to check for changes
      #
      # @return [Bool] Whether the podfile has changes respect to the lockfile.
      #
      def podfile_needs_install?(analysis_result)
        state = analysis_result.podfile_state
        needing_install = state.added + state.changed + state.deleted
        !needing_install.empty?
      end

      # @param  [AnalysisResult] analysis_result
      #         the analysis result to check for changes
      #
      # @return [Bool] Whether the sandbox is in synch with the lockfile.
      #
      def sandbox_needs_install?(analysis_result)
        state = analysis_result.sandbox_state
        needing_install = state.added + state.changed + state.deleted
        !needing_install.empty?
      end

      #-----------------------------------------------------------------------#

      # @!group Configuration

      # @return [Hash, Boolean, nil] Pods that have been requested to be
      #         updated or true if all Pods should be updated
      #
      attr_accessor :update

      # @return [Bool] Whether the version of the dependencies which did not
      #         change in the Podfile should be locked.
      #
      def update_mode?
        update != nil
      end

      # @return [Symbol] Whether and how the dependencies in the Podfile
      #                  should be updated.
      #
      def update_mode
        if !update
          :none
        elsif update == true
          :all
        elsif !update[:pods].nil?
          :selected
        end
      end

      # @return [Bool] Whether the analysis allows pre-downloads and thus
      #         modifications to the sandbox.
      #
      # @note   This flag should not be used in installations.
      #
      # @note   This is used by the `pod outdated` command to prevent
      #         modification of the sandbox in the resolution process.
      #
      attr_accessor :allow_pre_downloads
      alias_method :allow_pre_downloads?, :allow_pre_downloads

      #-----------------------------------------------------------------------#

      private

      def validate_podfile!
        validator = Installer::PodfileValidator.new(podfile)
        validator.validate

        unless validator.valid?
          raise Informative, validator.message
        end
      end

      # @!group Analysis steps

      # @note   The warning about the version of the Lockfile doesn't use the
      #         `UI.warn` method because it prints the output only at the end
      #         of the installation. At that time CocoaPods could have crashed.
      #
      def validate_lockfile_version!
        if lockfile && lockfile.cocoapods_version > Version.new(VERSION)
          STDERR.puts '[!] The version of CocoaPods used to generate ' \
            "the lockfile (#{lockfile.cocoapods_version}) is "\
            "higher than the version of the current executable (#{VERSION}). " \
            'Incompatibility issues may arise.'.yellow
        end
      end

      # Compares the {Podfile} with the {Lockfile} in order to detect which
      # dependencies should be locked.
      #
      # @return [SpecsState] the states of the Podfile specs.
      #
      # @note   As the target definitions share the same sandbox they should have
      #         the same version of a Pod. For this reason this method returns
      #         the name of the Pod (root name of the dependencies) and doesn't
      #         group them by target definition.
      #
      # @todo   [CocoaPods > 0.18] If there isn't a Lockfile all the Pods should
      #         be marked as added.
      #
      def generate_podfile_state
        if lockfile
          pods_state = nil
          UI.section 'Finding Podfile changes' do
            pods_by_state = lockfile.detect_changes_with_podfile(podfile)
            pods_state = SpecsState.new(pods_by_state)
            pods_state.print
          end
          pods_state
        else
          state = SpecsState.new
          state.added.concat(podfile.dependencies.map(&:name).uniq)
          state
        end
      end

      public

      # Updates the git source repositories unless the config indicates to skip it.
      #
      def update_repositories
        sources.each do |source|
          if SourcesManager.git_repo?(source.repo)
            SourcesManager.update(source.name)
          else
            UI.message "Skipping `#{source.name}` update because the repository is not a git source repository."
          end
        end
      end

      private

      # Creates the models that represent the targets generated by CocoaPods.
      #
      # @return [Array<AggregateTarget>]
      #
      def generate_targets
        pod_targets = generate_pod_targets(result.specs_by_target)
        aggregate_targets = result.specs_by_target.keys.reject(&:abstract?).map do |target_definition|
          generate_target(target_definition, pod_targets)
        end
        aggregate_targets.each do |target|
          target.search_paths_aggregate_targets = aggregate_targets.select do |aggregate_target|
            target.target_definition.targets_to_inherit_search_paths.include?(aggregate_target.target_definition)
          end
        end
      end

      # Setup the aggregate target for a single user target
      #
      # @param  [TargetDefinition] target_definition
      #         the target definition for the user target.
      #
      # @param  [Array<PodTarget>] pod_targets
      #         the pod targets, which were generated.
      #
      # @return [AggregateTarget]
      #
      def generate_target(target_definition, pod_targets)
        target = AggregateTarget.new(target_definition, sandbox)
        target.host_requires_frameworks |= target_definition.uses_frameworks?

        if config.integrate_targets?
          target_inspection = result.target_inspections[target_definition]
          raise "missing inspection: #{target_definition.name}" unless target_inspection
          target.user_project = target_inspection.project
          target.client_root = target.user_project_path.dirname.realpath
          target.user_target_uuids = target_inspection.project_target_uuids
          target.user_build_configurations = target_inspection.build_configurations
          target.archs = target_inspection.archs
        else
          target.client_root = config.installation_root.realpath
          target.user_target_uuids = []
          target.user_build_configurations = target_definition.build_configurations || { 'Release' => :release, 'Debug' => :debug }
          if target_definition.platform && target_definition.platform.name == :osx
            target.archs = '$(ARCHS_STANDARD_64_BIT)'
          end
        end

        target.pod_targets = pod_targets.select do |pod_target|
          pod_target.target_definitions.include?(target_definition)
        end
        target
      end

      # Setup the pod targets for an aggregate target. Deduplicates resulting
      # targets by grouping by grouping by platform and subspec by their root
      # to create a {PodTarget} for each spec.
      #
      # @param  [Hash{Podfile::TargetDefinition => Array<Specification>}] specs_by_target
      #         the resolved specifications grouped by target.
      #
      # @return [Array<PodTarget>]
      #
      def generate_pod_targets(specs_by_target)
        if config.deduplicate_targets?
          dedupe_cache = {}

          all_specs = specs_by_target.flat_map do |target_definition, dependent_specs|
            dependent_specs.group_by(&:root).map do |root_spec, specs|
              [root_spec, specs, target_definition]
            end
          end

          distinct_targets = all_specs.each_with_object({}) do |dependency, hash|
            root_spec, specs, target_definition = *dependency
            hash[root_spec] ||= {}
            (hash[root_spec][[specs, target_definition.platform]] ||= []) << target_definition
          end

          pod_targets = distinct_targets.flat_map do |_, targets_by_distinctors|
            if targets_by_distinctors.count > 1
              # There are different sets of subspecs or the spec is used across different platforms
              targets_by_distinctors.flat_map do |distinctor, target_definitions|
                specs, = *distinctor
                generate_pod_target(target_definitions, specs).scoped(dedupe_cache)
              end
            else
              (specs, _), target_definitions = targets_by_distinctors.first
              generate_pod_target(target_definitions, specs)
            end
          end

          # A `PodTarget` can't be deduplicated if any of its
          # transitive dependencies can't be deduplicated.
          pod_targets.flat_map do |target|
            dependent_targets = transitive_dependencies_for_pod_target(target, pod_targets)
            target.dependent_targets = dependent_targets
            if dependent_targets.any?(&:scoped?)
              target.scoped(dedupe_cache)
            else
              target
            end
          end
        else
          pod_targets = specs_by_target.flat_map do |target_definition, specs|
            grouped_specs = specs.group_by.group_by(&:root).values.uniq
            grouped_specs.flat_map do |pod_specs|
              generate_pod_target([target_definition], pod_specs).scoped(dedupe_cache)
            end
          end
          pod_targets.each do |target|
            target.dependent_targets = transitive_dependencies_for_pod_target(target, pod_targets)
          end
        end
      end

      # Finds the names of the Pods upon which the given target _transitively_
      # depends.
      #
      # @note: This is implemented in the analyzer, because we don't have to
      #        care about the requirements after dependency resolution.
      #
      # @param  [PodTarget] pod_target
      #         The pod target, whose dependencies should be returned.
      #
      # @param  [Array<PodTarget>] targets
      #         All pod targets, which are integrated alongside.
      #
      # @return [Array<PodTarget>]
      #
      def transitive_dependencies_for_pod_target(pod_target, targets)
        if targets.any?
          dependent_targets = pod_target.dependencies.flat_map do |dep|
            next [] if pod_target.pod_name == dep
            targets.select { |t| t.pod_name == dep }
          end
          remaining_targets = targets - dependent_targets
          dependent_targets += dependent_targets.flat_map do |target|
            transitive_dependencies_for_pod_target(target, remaining_targets)
          end
          dependent_targets.uniq
        else
          []
        end
      end

      # Create a target for each spec group
      #
      # @param  [TargetDefinitions] target_definitions
      #         the aggregate target
      #
      # @param  [Array<Specification>] specs
      #         the specifications of an equal root.
      #
      # @return [PodTarget]
      #
      def generate_pod_target(target_definitions, pod_specs)
        pod_target = PodTarget.new(pod_specs, target_definitions, sandbox)

        if config.integrate_targets?
          target_inspections = result.target_inspections.select { |t, _| target_definitions.include?(t) }.values
          pod_target.user_build_configurations = target_inspections.map(&:build_configurations).reduce({}, &:merge)
          pod_target.archs = target_inspections.flat_map(&:archs).compact.uniq.sort
        else
          pod_target.user_build_configurations = {}
          if target_definitions.first.platform.name == :osx
            pod_target.archs = '$(ARCHS_STANDARD_64_BIT)'
          end
        end

        pod_target
      end

      # Generates dependencies that require the specific version of the Pods
      # that haven't changed in the {Lockfile}.
      #
      # These dependencies are passed to the {Resolver}, unless the installer
      # is in update mode, to prevent it from upgrading the Pods that weren't
      # changed in the {Podfile}.
      #
      # @return [Molinillo::DependencyGraph<Dependency>] the dependencies
      #         generated by the lockfile that prevent the resolver to update
      #         a Pod.
      #
      def generate_version_locking_dependencies
        if update_mode == :all || !lockfile
          LockingDependencyAnalyzer.unlocked_dependency_graph
        else
          pods_to_update = result.podfile_state.changed + result.podfile_state.deleted
          pods_to_update += update[:pods] if update_mode == :selected
          pods_to_update += podfile.dependencies.select(&:local?).map(&:name)
          LockingDependencyAnalyzer.generate_version_locking_dependencies(lockfile, pods_to_update)
        end
      end

      # Fetches the podspecs of external sources if modifications to the
      # sandbox are allowed.
      #
      # @note   In update mode all the external sources are refreshed while in
      #         normal mode they are refreshed only if added or changed in the
      #         Podfile. Moreover, in normal specifications for unchanged Pods
      #         which are missing or are generated from an local source are
      #         fetched as well.
      #
      # @note   It is possible to perform this step before the resolution
      #         process because external sources identify a single specific
      #         version (checkout). If the other dependencies are not
      #         compatible with the version reported by the podspec of the
      #         external source the resolver will raise.
      #
      # @return [void]
      #
      # TODO:    Specs
      #
      def fetch_external_sources
        return unless allow_pre_downloads?

        verify_no_pods_with_different_sources!
        unless dependencies_to_fetch.empty?
          UI.section 'Fetching external sources' do
            dependencies_to_fetch.sort.each do |dependency|
              fetch_external_source(dependency, !pods_to_fetch.include?(dependency.name))
            end
          end
        end
      end

      def verify_no_pods_with_different_sources!
        deps_with_different_sources = podfile.dependencies.group_by(&:root_name).
          select { |_root_name, dependencies| dependencies.map(&:external_source).uniq.count > 1 }
        deps_with_different_sources.each do |root_name, dependencies|
          raise Informative, 'There are multiple dependencies with different ' \
          "sources for `#{root_name}` in #{UI.path podfile.defined_in_file}:" \
          "\n\n- #{dependencies.map(&:to_s).join("\n- ")}"
        end
      end

      def fetch_external_source(dependency, use_lockfile_options)
        checkout_options = lockfile.checkout_options_for_pod_named(dependency.root_name) if lockfile
        if checkout_options && use_lockfile_options
          source = ExternalSources.from_params(checkout_options, dependency, podfile.defined_in_file)
        else
          source = ExternalSources.from_dependency(dependency, podfile.defined_in_file)
        end
        source.fetch(sandbox)
      end

      def dependencies_to_fetch
        @deps_to_fetch ||= begin
          deps_to_fetch = []
          deps_with_external_source = podfile.dependencies.select(&:external_source)

          if update_mode == :all
            deps_to_fetch = deps_with_external_source
          else
            deps_to_fetch = deps_with_external_source.select { |dep| pods_to_fetch.include?(dep.name) }
            deps_to_fetch_if_needed = deps_with_external_source.select { |dep| result.podfile_state.unchanged.include?(dep.name) }
            deps_to_fetch += deps_to_fetch_if_needed.select do |dep|
              sandbox.specification(dep.name).nil? ||
                !dep.external_source[:local].nil? ||
                !dep.external_source[:path].nil? ||
                !sandbox.pod_dir(dep.root_name).directory? ||
                checkout_requires_update?(dep)
            end
          end
          deps_to_fetch.uniq(&:root_name)
        end
      end

      def checkout_requires_update?(dependency)
        return true unless lockfile && sandbox.manifest
        locked_checkout_options = lockfile.checkout_options_for_pod_named(dependency.root_name)
        sandbox_checkout_options = sandbox.manifest.checkout_options_for_pod_named(dependency.root_name)
        locked_checkout_options != sandbox_checkout_options
      end

      def pods_to_fetch
        @pods_to_fetch ||= begin
          pods_to_fetch = result.podfile_state.added + result.podfile_state.changed
          if update_mode == :selected
            pods_to_fetch += update[:pods]
          elsif update_mode == :all
            pods_to_fetch += result.podfile_state.unchanged + result.podfile_state.deleted
          end
          pods_to_fetch
        end
      end

      def store_existing_checkout_options
        podfile.dependencies.select(&:external_source).each do |dep|
          if checkout_options = lockfile && lockfile.checkout_options_for_pod_named(dep.root_name)
            sandbox.store_checkout_source(dep.root_name, checkout_options)
          end
        end
      end

      # Converts the Podfile in a list of specifications grouped by target.
      #
      # @note   As some dependencies might have external sources the resolver
      #         is aware of the {Sandbox} and interacts with it to download the
      #         podspecs of the external sources. This is necessary because the
      #         resolver needs their specifications to analyze their
      #         dependencies.
      #
      # @note   The specifications of the external sources which are added,
      #         modified or removed need to deleted from the sandbox before the
      #         resolution process. Otherwise the resolver might use an
      #         incorrect specification instead of pre-downloading it.
      #
      # @note   In update mode the resolver is set to always update the specs
      #         from external sources.
      #
      # @return [Hash{TargetDefinition => Array<Spec>}] the specifications
      #         grouped by target.
      #
      def resolve_dependencies
        duplicate_dependencies = podfile.dependencies.group_by(&:name).
          select { |_name, dependencies| dependencies.count > 1 }
        duplicate_dependencies.each do |name, dependencies|
          UI.warn "There are duplicate dependencies on `#{name}` in #{UI.path podfile.defined_in_file}:\n\n" \
           "- #{dependencies.map(&:to_s).join("\n- ")}"
        end

        specs_by_target = nil
        UI.section "Resolving dependencies of #{UI.path(podfile.defined_in_file) || 'Podfile'}" do
          resolver = Resolver.new(sandbox, podfile, locked_dependencies, sources)
          specs_by_target = resolver.resolve
          specs_by_target.values.flatten(1).each(&:validate_cocoapods_version)
        end
        specs_by_target
      end

      # Warns for any specification that is incompatible with its target.
      #
      # @param  [Hash{TargetDefinition => Array<Spec>}] specs_by_target
      #         the specifications grouped by target.
      #
      # @return [Hash{TargetDefinition => Array<Spec>}] the specifications
      #         grouped by target.
      #
      def validate_platforms(specs_by_target)
        specs_by_target.each do |target, specs|
          specs.each do |spec|
            unless spec.available_platforms.any? { |p| target.platform.supports?(p) }
              UI.warn "The platform of the target `#{target.name}` "     \
                "(#{target.platform}) may not be compatible with `#{spec}` which has "  \
                "a minimum requirement of #{spec.available_platforms.join(' - ')}."
            end
          end
        end
      end

      # Returns the list of all the resolved the resolved specifications.
      #
      # @return [Array<Specification>] the list of the specifications.
      #
      def generate_specifications
        result.specs_by_target.values.flatten.uniq
      end

      # Computes the state of the sandbox respect to the resolved
      # specifications.
      #
      # @return [SpecsState] the representation of the state of the manifest
      #         specifications.
      #
      def generate_sandbox_state
        sandbox_state = nil
        UI.section 'Comparing resolved specification to the sandbox manifest' do
          sandbox_analyzer = SandboxAnalyzer.new(sandbox, result.specifications, update_mode?, lockfile)
          sandbox_state = sandbox_analyzer.analyze
          sandbox_state.print
        end
        sandbox_state
      end

      #-----------------------------------------------------------------------#

      # @!group Analysis internal products

      # @return [Molinillo::DependencyGraph<Dependency>] the dependencies
      #         generated by the lockfile that prevent the resolver to update a
      #         Pod.
      #
      attr_reader :locked_dependencies

      #-----------------------------------------------------------------------#

      public

      # Returns the sources used to query for specifications
      #
      # When no explicit Podfile sources are defined, this defaults to the
      # master spec repository.
      # available sources ({SourcesManager.all}).
      #
      # @return [Array<Source>] the sources to be used in finding
      #         specifications, as specified by the {#podfile} or all sources.
      #
      def sources
        @sources ||= begin
          sources = podfile.sources

          # Add any sources specified using the :source flag on individual dependencies.
          dependency_sources = podfile.dependencies.map(&:podspec_repo).compact

          all_dependencies_have_sources = dependency_sources.count == podfile.dependencies.count
          if all_dependencies_have_sources
            sources = dependency_sources
          elsif sources.empty?
            sources = ['https://github.com/CocoaPods/Specs.git']
          else
            sources += dependency_sources
          end

          sources.uniq.map do |source_url|
            SourcesManager.find_or_create_source_with_url(source_url)
          end
        end
      end

      #-----------------------------------------------------------------------#

      private

      # @!group Analysis sub-steps

      # Checks whether the platform is specified if not integrating
      #
      # @return [void]
      #
      def verify_platforms_specified!
        unless config.integrate_targets?
          podfile.target_definition_list.each do |target_definition|
            if !target_definition.empty? && target_definition.platform.nil?
              raise Informative, 'It is necessary to specify the platform in the Podfile if not integrating.'
            end
          end
        end
      end

      # Precompute information for each target_definition in the Podfile
      #
      # @note The platforms are computed and added to each target_definition
      #       because it might be necessary to infer the platform from the
      #       user targets.
      #
      # @return [Hash{TargetDefinition => TargetInspectionResult}]
      #
      def inspect_targets_to_integrate
        inspection_result = {}
        UI.section 'Inspecting targets to integrate' do
          inspectors = podfile.target_definition_list.map do |target_definition|
            next if target_definition.abstract?
            TargetInspector.new(target_definition, config.installation_root)
          end.compact
          inspectors.group_by(&:compute_project_path).each do |project_path, target_inspectors|
            project = Xcodeproj::Project.open(project_path)
            target_inspectors.each do |inspector|
              target_definition = inspector.target_definition
              inspector.user_project = project
              results = inspector.compute_results
              inspection_result[target_definition] = results
              UI.message('Using `ARCHS` setting to build architectures of ' \
                "target `#{target_definition.label}`: (`#{results.archs.join('`, `')}`)")
            end
          end
        end
        inspection_result
      end
    end
  end
end
