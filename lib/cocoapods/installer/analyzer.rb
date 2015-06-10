module Pod
  class Installer
    # Analyzes the Podfile, the Lockfile, and the sandbox manifest to generate
    # the information relative to a CocoaPods installation.
    #
    class Analyzer
      include Config::Mixin

      autoload :SandboxAnalyzer, 'cocoapods/installer/analyzer/sandbox_analyzer'

      autoload :LockingDependencyAnalyzer, 'cocoapods/installer/analyzer/locking_dependency_analyzer'

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
        @archs_by_target_def = {}
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
        validate_lockfile_version!
        @result = AnalysisResult.new
        compute_target_platforms
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

      # Creates the models that represent the libraries generated by CocoaPods.
      #
      # @return [Array<Target>] the generated libraries.
      #
      def generate_targets
        targets = []
        result.specs_by_target.each do |target_definition, specs|
          targets << generate_target(target_definition, specs)
        end
        targets
      end

      # Setup the aggregate target for a single user target
      #
      # @param  [TargetDefinition] target_definition
      #         the target definition for the user target.
      #
      # @param  [Array<Specification>] specs
      #         the specifications that need to be installed grouped by the
      #         given target definition.
      #
      # @return [AggregateTarget]
      #
      def generate_target(target_definition, specs)
        target = AggregateTarget.new(target_definition, sandbox)
        target.host_requires_frameworks |= target_definition.uses_frameworks?

        if config.integrate_targets?
          project_path = compute_user_project_path(target_definition)
          user_project = Xcodeproj::Project.open(project_path)
          native_targets = compute_user_project_targets(target_definition, user_project)

          target.user_project_path = project_path
          target.client_root = project_path.dirname
          target.user_target_uuids = native_targets.map(&:uuid)
          target.user_build_configurations = compute_user_build_configurations(target_definition, native_targets)
          target.archs = @archs_by_target_def[target_definition]
        else
          target.client_root = config.installation_root
          target.user_target_uuids = []
          target.user_build_configurations = target_definition.build_configurations || { 'Release' => :release, 'Debug' => :debug }
          if target_definition.platform.name == :osx
            target.archs = '$(ARCHS_STANDARD_64_BIT)'
          end
        end

        target.pod_targets = generate_pod_targets(target, specs)

        target
      end

      # Setup the pod targets for an aggregate target. Group specs and subspecs
      # by their root to create a {PodTarget} for each spec.
      #
      # @param  [AggregateTarget] target
      #         the aggregate target
      #
      # @param  [Array<Specification>] specs
      #         the specifications that need to be installed.
      #
      # @return [Array<PodTarget>]
      #
      def generate_pod_targets(target, specs)
        grouped_specs = specs.group_by(&:root).values.uniq
        grouped_specs.map do |pod_specs|
          generate_pod_target(target, pod_specs)
        end
      end

      # Create a target for each spec group and add it to the aggregate target
      #
      # @param  [AggregateTarget] target
      #         the aggregate target
      #
      # @param  [Array<Specification>] specs
      #         the specifications of an equal root.
      #
      # @return [PodTarget]
      #
      def generate_pod_target(target, pod_specs)
        pod_target = PodTarget.new(pod_specs, target.target_definition, sandbox)

        if config.integrate_targets?
          pod_target.user_build_configurations = target.user_build_configurations
          pod_target.archs = @archs_by_target_def[target.target_definition]
        else
          pod_target.user_build_configurations = {}
          if target.platform.name == :osx
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
        UI.section "Resolving dependencies of #{UI.path podfile.defined_in_file}" do
          resolver = Resolver.new(sandbox, podfile, locked_dependencies, sources)
          specs_by_target = resolver.resolve
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
          sandbox_analyzer = SandboxAnalyzer.new(sandbox, result.specifications, update_mode?)
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
          if sources.empty?
            url = 'https://github.com/CocoaPods/Specs.git'
            [SourcesManager.find_or_create_source_with_url(url)]
          else
            sources.map do |source_url|
              SourcesManager.find_or_create_source_with_url(source_url)
            end
          end
        end
      end

      #-----------------------------------------------------------------------#

      private

      # @!group Analysis sub-steps

      # Returns the path of the user project that the {TargetDefinition}
      # should integrate.
      #
      # @raise  If the project is implicit and there are multiple projects.
      #
      # @raise  If the path doesn't exits.
      #
      # @return [Pathname] the path of the user project.
      #
      def compute_user_project_path(target_definition)
        if target_definition.user_project_path
          path = config.installation_root + target_definition.user_project_path
          path = "#{path}.xcodeproj" unless File.extname(path) == '.xcodeproj'
          path = Pathname.new(path)
          unless path.exist?
            raise Informative, 'Unable to find the Xcode project ' \
              "`#{path}` for the target `#{target_definition.label}`."
          end
        else
          xcodeprojs = config.installation_root.children.select { |e| e.fnmatch('*.xcodeproj') }
          if xcodeprojs.size == 1
            path = xcodeprojs.first
          else
            raise Informative, 'Could not automatically select an Xcode project. ' \
              "Specify one in your Podfile like so:\n\n" \
              "    xcodeproj 'path/to/Project.xcodeproj'\n"
          end
        end
        path
      end

      # Returns a list of the targets from the project of {TargetDefinition}
      # that needs to be integrated.
      #
      # @note   The method first looks if there is a target specified with
      #         the `link_with` option of the {TargetDefinition}. Otherwise
      #         it looks for the target that has the same name of the target
      #         definition.  Finally if no target was found the first
      #         encountered target is returned (it is assumed to be the one
      #         to integrate in simple projects).
      #
      # @note   This will only return targets that do **not** already have
      #         the Pods library in their frameworks build phase.
      #
      #
      def compute_user_project_targets(target_definition, user_project)
        if link_with = target_definition.link_with
          targets = native_targets(user_project).select { |t| link_with.include?(t.name) }
          raise Informative, "Unable to find the targets named `#{link_with.to_sentence}` to link with target definition `#{target_definition.name}`" if targets.empty?
        elsif target_definition.link_with_first_target?
          targets = [native_targets(user_project).first].compact
          raise Informative, 'Unable to find a target' if targets.empty?
        else
          target = native_targets(user_project).find { |t| t.name == target_definition.name.to_s }
          targets = [target].compact
          raise Informative, "Unable to find a target named `#{target_definition.name}`" if targets.empty?
        end
        targets
      end

      # @return [Array<PBXNativeTarget>] Returns the user’s targets, excluding
      #         aggregate targets.
      #
      def native_targets(user_project)
        user_project.targets.reject do |target|
          target.is_a? Xcodeproj::Project::Object::PBXAggregateTarget
        end
      end

      # Checks if any of the targets for the {TargetDefinition} computed before
      # by #compute_user_project_targets require to be build as a framework due
      # the presence of Swift source code in any of the source build phases.
      #
      # @param  [TargetDefinition] target_definition
      #         the target definition
      #
      # @param  [Array<PBXNativeTarget>] native_targets
      #         the targets which are checked for presence of Swift source code
      #
      # @return [Boolean] Whether the user project targets to integrate into
      #         uses Swift
      #
      def compute_user_project_targets_require_framework(target_definition, native_targets)
        file_predicate = nil
        file_predicate = proc do |file_ref|
          if file_ref.respond_to?(:last_known_file_type)
            file_ref.last_known_file_type == 'sourcecode.swift'
          elsif file_ref.respond_to?(:files)
            file_ref.files.any?(&file_predicate)
          else
            false
          end
        end
        target_definition.platform.supports_dynamic_frameworks? || native_targets.any? do |target|
          target.source_build_phase.files.any? do |build_file|
            file_predicate.call(build_file.file_ref)
          end
        end
      end

      # @return [Hash{String=>Symbol}] A hash representing the user build
      #         configurations where each key corresponds to the name of a
      #         configuration and its value to its type (`:debug` or `:release`).
      #
      def compute_user_build_configurations(target_definition, user_targets)
        if user_targets
          user_targets.map { |t| t.build_configurations.map(&:name) }.flatten.reduce({}) do |hash, name|
            hash[name] = name == 'Debug' ? :debug : :release
            hash
          end.merge(target_definition.build_configurations || {})
        else
          target_definition.build_configurations || {}
        end
      end

      # @return [Platform] The platform for the library.
      #
      # @note   This resolves to the lowest deployment target across the user
      #         targets.
      #
      # @todo   Is assigning the platform to the target definition the best way
      #         to go?
      #
      def compute_platform_for_target_definition(target_definition, user_targets)
        return target_definition.platform if target_definition.platform
        name = nil
        deployment_target = nil

        user_targets.each do |target|
          name ||= target.platform_name
          raise Informative, 'Targets with different platforms' unless name == target.platform_name
          if !deployment_target || deployment_target > Version.new(target.deployment_target)
            deployment_target = Version.new(target.deployment_target)
          end
        end

        target_definition.set_platform(name, deployment_target)
        Platform.new(name, deployment_target)
      end

      # @return [Platform] The platform for the library.
      #
      # @note   This resolves to the lowest deployment target across the user
      #         targets.
      #
      # @todo   Is assigning the platform to the target definition the best way
      #         to go?
      #
      def compute_archs_for_target_definition(target_definition, user_targets)
        archs = []
        user_targets.each do |target|
          target_archs = target.common_resolved_build_setting('ARCHS')
          archs.concat(Array(target_archs))
        end

        archs = archs.compact.uniq.sort
        UI.message('Using `ARCHS` setting to build architectures of ' \
                   "target `#{target_definition.label}`: " \
                   "(`#{archs.join('`, `')}`)")
        archs.length > 1 ? archs : archs.first
      end

      # Precompute the platforms for each target_definition in the Podfile
      #
      # @note The platforms are computed and added to each target_definition
      #       because it might be necessary to infer the platform from the
      #       user targets.
      #
      # @return [void]
      #
      def compute_target_platforms
        UI.section 'Inspecting targets to integrate' do
          podfile.target_definition_list.each do |target_definition|
            if config.integrate_targets?
              project_path = compute_user_project_path(target_definition)
              user_project = Xcodeproj::Project.open(project_path)
              targets = compute_user_project_targets(target_definition, user_project)
              compute_platform_for_target_definition(target_definition, targets)
              archs = compute_archs_for_target_definition(target_definition, targets)
              @archs_by_target_def[target_definition] = archs
            else
              unless target_definition.platform
                raise Informative, 'It is necessary to specify the platform in the Podfile if not integrating.'
              end
            end
          end
        end
      end

      #-----------------------------------------------------------------------#

      class AnalysisResult
        # @return [SpecsState] the states of the Podfile specs.
        #
        attr_accessor :podfile_state

        # @return [Hash{TargetDefinition => Array<Spec>}] the specifications
        #         grouped by target.
        #
        attr_accessor :specs_by_target

        # @return [Array<Specification>] the specifications of the resolved
        #         version of Pods that should be installed.
        #
        attr_accessor :specifications

        # @return [SpecsState] the states of the {Sandbox} respect the resolved
        #         specifications.
        #
        attr_accessor :sandbox_state

        # @return [Array<Target>] The Podfile targets containing library
        #         dependencies.
        #
        attr_accessor :targets

        # @return [Hash{String=>Symbol}] A hash representing all the user build
        #         configurations across all integration targets. Each key
        #         corresponds to the name of a configuration and its value to
        #         its type (`:debug` or `:release`).
        #
        def all_user_build_configurations
          targets.reduce({}) do |result, target|
            result.merge(target.user_build_configurations)
          end
        end
      end

      #-----------------------------------------------------------------------#

      # This class represents the state of a collection of Pods.
      #
      # @note The names of the pods stored by this class are always the **root**
      #       name of the specification.
      #
      # @note The motivation for this class is to ensure that the names of the
      #       subspecs are added instead of the name of the Pods.
      #
      class SpecsState
        # Initialize a new instance
        #
        # @param  [Hash{Symbol=>String}] pods_by_state
        #         The name of the pods grouped by their state
        #         (`:added`, `:removed`, `:changed` or `:unchanged`).
        #
        def initialize(pods_by_state = nil)
          @added     = []
          @deleted   = []
          @changed   = []
          @unchanged = []

          if pods_by_state
            @added     = pods_by_state[:added]     || []
            @deleted   = pods_by_state[:removed]   || []
            @changed   = pods_by_state[:changed]   || []
            @unchanged = pods_by_state[:unchanged] || []
          end
        end

        # @return [Array<String>] the names of the pods that were added.
        #
        attr_accessor :added

        # @return [Array<String>] the names of the pods that were changed.
        #
        attr_accessor :changed

        # @return [Array<String>] the names of the pods that were deleted.
        #
        attr_accessor :deleted

        # @return [Array<String>] the names of the pods that were unchanged.
        #
        attr_accessor :unchanged

        # Displays the state of each pod.
        #
        # @return [void]
        #
        def print
          added    .sort.each { |pod| UI.message('A'.green  + " #{pod}", '', 2) }
          deleted  .sort.each { |pod| UI.message('R'.red    + " #{pod}", '', 2) }
          changed  .sort.each { |pod| UI.message('M'.yellow + " #{pod}", '', 2) }
          unchanged.sort.each { |pod| UI.message('-'        + " #{pod}", '', 2) }
        end

        # Adds the name of a Pod to the give state.
        #
        # @param  [String] name
        #         the name of the Pod.
        #
        # @param  [Symbol] state
        #         the state of the Pod.
        #
        # @return [void]
        #
        def add_name(name, state)
          send(state) << name
        end
      end
    end
  end
end
