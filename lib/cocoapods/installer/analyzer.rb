module Pod
  class Installer
    # Analyzes the Podfile, the Lockfile, and the sandbox manifest to generate
    # the information relative to a CocoaPods installation.
    #
    class Analyzer
      include Config::Mixin
      include InstallationOptions::Mixin

      delegate_installation_options { podfile }

      autoload :AnalysisResult,            'cocoapods/installer/analyzer/analysis_result'
      autoload :SandboxAnalyzer,           'cocoapods/installer/analyzer/sandbox_analyzer'
      autoload :SpecsState,                'cocoapods/installer/analyzer/specs_state'
      autoload :LockingDependencyAnalyzer, 'cocoapods/installer/analyzer/locking_dependency_analyzer'
      autoload :PodVariant,                'cocoapods/installer/analyzer/pod_variant'
      autoload :PodVariantSet,             'cocoapods/installer/analyzer/pod_variant_set'
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
        if installation_options.integrate_targets?
          @result.target_inspections = inspect_targets_to_integrate
        else
          verify_platforms_specified!
        end
        @result.podfile_state = generate_podfile_state

        store_existing_checkout_options
        fetch_external_sources if allow_fetches

        @locked_dependencies    = generate_version_locking_dependencies
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
        validator.warnings.uniq.each { |w| UI.warn(w) }
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
          state.added.merge(podfile.dependencies.map(&:root_name))
          state
        end
      end

      public

      # Updates the git source repositories.
      #
      def update_repositories
        sources.each do |source|
          if source.git?
            config.sources_manager.update(source.name)
          else
            UI.message "Skipping `#{source.name}` update because the repository is not a git source repository."
          end
        end
      end

      private

      # Copies the pod_targets of any of the app embedded aggregate targets into
      # their potential host aggregate target, if that potential host aggregate target's
      # user_target hosts any of the app embedded aggregate targets' user_targets
      #
      # @param  [AggregateTarget] aggregate_target the aggregate target whose user_target
      #         might host one or more of the embedded aggregate targets' user_targets
      #
      # @param  [Array<AggregateTarget>] embedded_aggregate_targets the aggregate targets
      #         representing the embedded targets to be integrated
      #
      def copy_embedded_target_pod_targets_to_host(aggregate_target, embedded_aggregate_targets)
        return if aggregate_target.requires_host_target?
        # Get the uuids of the aggregate_target's user_targets' embedded targets if any
        embedded_uuids = Set.new(aggregate_target.user_targets.map do |target|
          aggregate_target.user_project.embedded_targets_in_native_target(target).map(&:uuid)
        end.flatten)
        return if embedded_uuids.empty?
        embedded_aggregate_targets.each do |embedded_target|
          next unless embedded_target.user_targets.map(&:uuid).any? do |embedded_uuid|
            embedded_uuids.include? embedded_uuid
          end
          raise Informative, "#{aggregate_target.name} must call use_frameworks! because it is hosting an embedded target that calls use_frameworks!." unless aggregate_target.requires_frameworks?
          pod_target_names = aggregate_target.pod_targets.map(&:name)
          # This embedded target is hosted by the aggregate target's user_target; copy over the non-duplicate pod_targets
          aggregate_target.pod_targets = aggregate_target.pod_targets + embedded_target.pod_targets.select do |pod_target|
            !pod_target_names.include? pod_target.name
          end
        end
      end

      # Raises an error if there are embedded targets in the Podfile, but
      # their host targets have not been declared in the Podfile
      #
      # @param  [Array<AggregateTarget>] aggregate_targets the generated
      #         aggregate targets
      #
      # @param  [Array<AggregateTarget>] embedded_aggregate_targets the aggregate targets
      #         representing the embedded targets to be integrated
      #
      def verify_host_targets_in_podfile(aggregate_targets, embedded_aggregate_targets)
        aggregate_target_uuids = Set.new aggregate_targets.map(&:user_targets).flatten.map(&:uuid)
        embedded_targets_missing_hosts = []
        embedded_aggregate_targets.each do |target|
          host_uuids = target.user_targets.map do |user_target|
            target.user_project.host_targets_for_embedded_target(user_target).map(&:uuid)
          end.flatten
          embedded_targets_missing_hosts << target unless host_uuids.any? do |uuid|
            aggregate_target_uuids.include? uuid
          end
        end
        unless embedded_targets_missing_hosts.empty?
          raise Informative, "Unable to find host target for #{embedded_targets_missing_hosts.map(&:name).join(', ')}. Please add the host targets for the embedded targets to the Podfile."
        end
      end

      # Creates the models that represent the targets generated by CocoaPods.
      #
      # @return [Array<AggregateTarget>]
      #
      def generate_targets
        specs_by_target = result.specs_by_target.reject { |td, _| td.abstract? }
        pod_targets = generate_pod_targets(specs_by_target)
        aggregate_targets = specs_by_target.keys.map do |target_definition|
          generate_target(target_definition, pod_targets)
        end
        if installation_options.integrate_targets?
          # Copy embedded target pods that cannot have their pods embedded as frameworks to their host targets
          embedded_targets = aggregate_targets.select(&:requires_host_target?).select(&:requires_frameworks?)
          verify_host_targets_in_podfile(aggregate_targets, embedded_targets)
          aggregate_targets.each do |target|
            copy_embedded_target_pod_targets_to_host(target, embedded_targets)
          end
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

        if installation_options.integrate_targets?
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
        if installation_options.deduplicate_targets?
          distinct_targets = specs_by_target.each_with_object({}) do |dependency, hash|
            target_definition, dependent_specs = *dependency
            dependent_specs.group_by(&:root).each do |root_spec, specs|
              pod_variant = PodVariant.new(specs, target_definition.platform, target_definition.uses_frameworks?)
              hash[root_spec] ||= {}
              (hash[root_spec][pod_variant] ||= []) << target_definition
            end
          end

          pod_targets = distinct_targets.flat_map do |_root, target_definitions_by_variant|
            suffixes = PodVariantSet.new(target_definitions_by_variant.keys).scope_suffixes
            target_definitions_by_variant.flat_map do |variant, target_definitions|
              generate_pod_target(target_definitions, variant.specs, :scope_suffix => suffixes[variant])
            end
          end

          all_specs = specs_by_target.values.flatten.uniq
          pod_targets_by_name = pod_targets.group_by(&:pod_name).each_with_object({}) do |(name, values), hash|
            # Sort the target by the number of activated subspecs, so that
            # we prefer a minimal target as transitive dependency.
            hash[name] = values.sort_by { |pt| pt.specs.count }
          end
          pod_targets.each do |target|
            dependencies = transitive_dependencies_for_specs(target.specs, target.platform, all_specs).group_by(&:root)
            target.dependent_targets = dependencies.map do |root_spec, deps|
              pod_targets_by_name[root_spec.name].find do |t|
                next false if t.platform.symbolic_name != target.platform.symbolic_name ||
                    t.requires_frameworks? != target.requires_frameworks?
                spec_names = t.specs.map(&:name)
                deps.all? { |dep| spec_names.include?(dep.name) }
              end
            end
          end
        else
          dedupe_cache = {}
          specs_by_target.flat_map do |target_definition, specs|
            grouped_specs = specs.group_by(&:root).values.uniq
            pod_targets = grouped_specs.flat_map do |pod_specs|
              generate_pod_target([target_definition], pod_specs).scoped(dedupe_cache)
            end

            pod_targets.each do |target|
              dependencies = transitive_dependencies_for_specs(target.specs, target.platform, specs).group_by(&:root)
              target.dependent_targets = pod_targets.reject { |t| dependencies[t.root_spec].nil? }
            end
          end
        end
      end

      # Returns the specs upon which the given specs _transitively_ depend.
      #
      # @note: This is implemented in the analyzer, because we don't have to
      #        care about the requirements after dependency resolution.
      #
      # @param  [Array<Specification>] specs
      #         The specs, whose dependencies should be returned.
      #
      # @param  [Platform] platform
      #         The platform for which the dependencies should be returned.
      #
      # @param  [Array<Specification>] all_specs
      #         All specifications which are installed alongside.
      #
      # @return [Array<Specification>]
      #
      def transitive_dependencies_for_specs(specs, platform, all_specs)
        return [] if specs.empty? || all_specs.empty?
        dependent_specs = specs.flat_map do |spec|
          spec.consumer(platform).dependencies.flat_map do |dependency|
            all_specs.find do |s|
              next false if specs.include?(s)
              s.name == dependency.name
            end
          end.compact
        end.uniq
        remaining_specs = all_specs - dependent_specs
        dependent_specs + transitive_dependencies_for_specs(dependent_specs, platform, remaining_specs)
      end

      # Create a target for each spec group
      #
      # @param  [TargetDefinitions] target_definitions
      #         the aggregate target
      #
      # @param  [Array<Specification>] pod_specs
      #         the specifications of an equal root.
      #
      # @param  [String] scope_suffix
      #         @see PodTarget#scope_suffix
      #
      # @return [PodTarget]
      #
      def generate_pod_target(target_definitions, pod_specs, scope_suffix: nil)
        pod_target = PodTarget.new(pod_specs, target_definitions, sandbox, scope_suffix)
        pod_target.host_requires_frameworks = target_definitions.any?(&:uses_frameworks?)

        if installation_options.integrate_targets?
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
          local_pod_names = podfile.dependencies.select(&:local?).map(&:root_name)
          pods_to_unlock = local_pod_names.reject do |pod_name|
            sandbox.specification(pod_name).checksum == lockfile.checksum(pod_name)
          end
          LockingDependencyAnalyzer.generate_version_locking_dependencies(lockfile, pods_to_update, pods_to_unlock)
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
              fetch_external_source(dependency, !pods_to_fetch.include?(dependency.root_name))
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
        source = if checkout_options && use_lockfile_options
                   ExternalSources.from_params(checkout_options, dependency, podfile.defined_in_file)
                 else
                   ExternalSources.from_dependency(dependency, podfile.defined_in_file)
        end
        source.can_cache = installation_options.clean?
        source.fetch(sandbox)
      end

      def dependencies_to_fetch
        @deps_to_fetch ||= begin
          deps_to_fetch = []
          deps_with_external_source = podfile.dependencies.select(&:external_source)

          if update_mode == :all
            deps_to_fetch = deps_with_external_source
          else
            deps_to_fetch = deps_with_external_source.select { |dep| pods_to_fetch.include?(dep.root_name) }
            deps_to_fetch_if_needed = deps_with_external_source.select { |dep| result.podfile_state.unchanged.include?(dep.root_name) }
            deps_to_fetch += deps_to_fetch_if_needed.select do |dep|
              sandbox.specification(dep.root_name).nil? ||
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
          pods_to_fetch += podfile.dependencies.
            select { |dep| Hash(dep.external_source).key?(:podspec) && sandbox.specification_path(dep.root_name).nil? }.
            map(&:root_name)
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
            next unless target_platform = target.platform
            unless spec.available_platforms.any? { |p| target_platform.supports?(p) }
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
      # available sources ({config.sources_manager.all}).
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
            config.sources_manager.find_or_create_source_with_url(source_url)
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
        unless installation_options.integrate_targets?
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
