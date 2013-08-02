module Pod
  class Installer

    # Analyzes the Podfile, the Lockfile, and the sandbox manifest to generate
    # the information relative to a CocoaPods installation.
    #
    class Analyzer

      include Config::Mixin

      autoload :SandboxAnalyzer, 'cocoapods/installer/analyzer/sandbox_analyzer'
      autoload :UserProjectAnalyzer, 'cocoapods/installer/analyzer/user_project_analyzer'

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

      # @param  [Sandbox]  sandbox     @see sandbox
      # @param  [Podfile]  podfile     @see podfile
      # @param  [Lockfile] lockfile    @see lockfile
      #
      def initialize(sandbox, podfile, lockfile = nil)
        @sandbox  = sandbox
        @podfile  = podfile
        @lockfile = lockfile

        @update_mode = false
        @allow_pre_downloads = true
      end

      # Performs the analysis.
      #
      # The Podfile and the Lockfile provide the information necessary to
      # compute which specification should be installed. The manifest of the
      # sandbox returns which specifications are installed.
      #
      # @return [AnalysisResult]
      #
      def analyze(allow_fetches = true)
        update_repositories_if_needed if allow_fetches
        @result = AnalysisResult.new
        @result.podfile_state = generate_podfile_state
        @locked_dependencies = generate_version_locking_dependencies
        @target_definition_data = inspect_user_projects

        fetch_external_sources if allow_fetches
        @result.specs_by_target = resolve_dependencies
        @result.specifications = generate_specifications
        @result.targets = generate_targets
        @result.sandbox_state = generate_sandbox_state
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

      # @return [Bool] Whether the podfile has changes respect to the lockfile.
      #
      def podfile_needs_install?(analysis_result)
        state = analysis_result.podfile_state
        needing_install = state.added + state.changed + state.deleted
        !needing_install.empty?
      end

      # @return [Bool] Whether the sandbox is in synch with the lockfile.
      #
      def sandbox_needs_install?(analysis_result)
        state = analysis_result.sandbox_state
        needing_install = state.added + state.changed + state.deleted
        !needing_install.empty?
      end

      #-----------------------------------------------------------------------#

      # @!group Configuration

      # @return [Bool] Whether the version of the dependencies which did non
      #         change in the Podfile should be locked.
      #
      attr_accessor :update_mode
      alias_method  :update_mode?, :update_mode

      # @return [Bool] Whether the analysis allows pre-downloads and thus
      #         modifications to the sandbox.
      #
      # @note   This flag should not be used in installations.
      #
      # @note   This is used by the `pod outdated` command to prevent
      #         modification of the sandbox in the resolution process.
      #
      attr_accessor :allow_pre_downloads
      alias_method  :allow_pre_downloads?, :allow_pre_downloads

      #-----------------------------------------------------------------------#

      private

      # @!group Analysis steps

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
          UI.section "Finding Podfile changes" do
            pods_by_state = lockfile.detect_changes_with_podfile(podfile)
            pods_by_state.dup.each do |state, full_names|
              pods_by_state[state] = full_names.map { |fn| Specification.root_name(fn) }
            end
            pods_state = SpecsState.new(pods_by_state)
            pods_state.print
          end
          pods_state
        else
          state = SpecsState.new
          state.added.concat(podfile.dependencies.map(&:root_name).uniq)
          state
        end
      end

      # Updates the source repositories unless the config indicates to skip it.
      #
      # @return [void]
      #
      def update_repositories_if_needed
        unless config.skip_repo_update?
          UI.section 'Updating spec repositories' do
            SourcesManager.update
          end
        end
      end

      # Generates dependencies that require the specific version of the Pods
      # that haven't changed in the {Lockfile}.
      #
      # These dependencies are passed to the {Resolver}, unless the installer
      # is in update mode, to prevent it from upgrading the Pods that weren't
      # changed in the {Podfile}.
      #
      # @return [Array<Dependency>] the dependencies generate by the lockfile
      #         that prevent the resolver to update a Pod.
      #
      def generate_version_locking_dependencies
        if update_mode?
          []
        else
          result.podfile_state.unchanged.map do |pod|
            lockfile.dependency_to_lock_pod_named(pod)
          end
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
      def fetch_external_sources
        return unless allow_pre_downloads?
        deps_to_fetch = []
        deps_to_fetch_if_needed = []
        deps_with_external_source = podfile.dependencies.select { |dep| dep.external_source }
        if update_mode?
          deps_to_fetch = deps_with_external_source
        else
          pods_to_fetch = result.podfile_state.added + result.podfile_state.changed
          deps_to_fetch = deps_with_external_source.select { |dep| pods_to_fetch.include?(dep.root_name) }
          deps_to_fetch_if_needed = deps_with_external_source.select { |dep| result.podfile_state.unchanged.include?(dep.root_name) }
          deps_to_fetch += deps_to_fetch_if_needed.select { |dep| sandbox.specification(dep.root_name).nil? || !dep.external_source[:local].nil? || !dep.external_source[:path].nil? }
        end

        unless deps_to_fetch.empty?
          UI.section "Fetching external sources" do
            deps_to_fetch.uniq.sort.each do |dependency|
              source = ExternalSources.from_dependency(dependency, podfile.defined_in_file)
              source.fetch(sandbox)
            end
          end
        end
      end

      # Precomputes the platforms for each target_definition in the Podfile
      #
      # @note The platforms are computed and added to each target_definition
      #       because it might be necessary to infer the platform from the
      #       user targets.
      #
      # @return [void]
      #
      def inspect_user_projects
        if config.integrate_targets?
          user_project_analyzer = UserProjectAnalyzer.new(podfile.target_definition_list, config.installation_root)
          user_project_analyzer.analyze
        else
          podfile.target_definition_list.each do |target_definition|
            unless target_definition.platform
              raise Informative, "It is necessary to specify the platform in the Podfile if not integrating."
            end
          end
          {}
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
        specs_by_target = nil
        UI.section "Resolving dependencies of #{UI.path podfile.defined_in_file}" do
          resolver = Resolver.new(sandbox, podfile, locked_dependencies, target_definition_data)
          specs_by_target = resolver.resolve
        end
        specs_by_target
      end

      # Returns the list of all the resolved the resolved specifications.
      #
      # @return [Array<Specification>] the list of the specifications.
      #
      def generate_specifications
        result.specs_by_target.values.flatten.uniq
      end

      # Creates the models that represent the libraries generated by CocoaPods.
      #
      # @return [Array<Libraries>] the generated libraries.
      #
      def generate_targets
        targets = []
        result.specs_by_target.each do |target_definition, specs|
          target = AggregateTarget.new(target_definition, sandbox)
          targets << target

          definition_data = target_definition_data[target_definition]
          if config.integrate_targets?
            target.user_project_path = definition_data.project_path
            target.client_root = definition_data.project_path.dirname
            target.user_target_uuids = definition_data.targets.map(&:uuid)
            target.user_build_configurations = definition_data.build_configurations
            target.platform = definition_data.platform
          else
            target.client_root = config.installation_root
            target.user_target_uuids = []
            target.user_build_configurations = target_definition.build_configurations || {}
          end

          grouped_specs = specs.map do |spec|
            specs.select { |s| s.root == spec.root }
          end.uniq

          grouped_specs.each do |pod_specs|
            pod_target = PodTarget.new(pod_specs, target_definition, sandbox)
            pod_target.user_build_configurations = target.user_build_configurations
            # TODO: inherit
            pod_target.platform = target.platform

            target.pod_targets << pod_target
            pod_target.aggregate_target = target
          end
        end
        targets
      end

      # Computes the state of the sandbox respect to the resolved
      # specifications.
      #
      # @return [SpecsState] the representation of the state of the manifest
      #         specifications.
      #
      def generate_sandbox_state
        sandbox_state = nil
        UI.section "Comparing resolved specification to the sandbox manifest" do
          sandbox_analyzer = SandboxAnalyzer.new(sandbox, result.specifications, update_mode, lockfile)
          sandbox_state = sandbox_analyzer.analyze
          sandbox_state.print
        end
        sandbox_state
      end

      #-----------------------------------------------------------------------#

      # @!group Analysis internal products

      # @return [Array<Dependency>] the dependencies generate by the lockfile
      #         that prevent the resolver to update a Pod.
      #
      attr_reader :locked_dependencies

      attr_reader :target_definition_data


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

        # @param  [Hash{Symbol=>String}] pods_by_state
        #         The **root** name of the pods grouped by their state
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
          added    .sort.each { |pod| UI.message("A".green  + " #{pod}", '', 2) }
          deleted  .sort.each { |pod| UI.message("R".red    + " #{pod}", '', 2) }
          changed  .sort.each { |pod| UI.message("M".yellow + " #{pod}", '', 2) }
          unchanged.sort.each { |pod| UI.message("-"        + " #{pod}", '', 2) }
        end

        # Adds the name of a Pod to the give state.
        #
        # @param  [String]
        #         the name of the Pod.
        #
        # @param  [Symbol]
        #         the state of the Pod.
        #
        # @raise  If there is an attempt to add the name of a subspec.
        #
        # @return [void]
        #
        def add_name(name, state)
          raise "[Bug] Attempt to add subspec to the pods state" if name.include?('/')
          self.send(state) << name
        end

      end
    end
  end
end
