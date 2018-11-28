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
      autoload :LockingDependencyAnalyzer, 'cocoapods/installer/analyzer/locking_dependency_analyzer'
      autoload :PodfileDependencyCache,    'cocoapods/installer/analyzer/podfile_dependency_cache'
      autoload :PodVariant,                'cocoapods/installer/analyzer/pod_variant'
      autoload :PodVariantSet,             'cocoapods/installer/analyzer/pod_variant_set'
      autoload :SandboxAnalyzer,           'cocoapods/installer/analyzer/sandbox_analyzer'
      autoload :SpecsState,                'cocoapods/installer/analyzer/specs_state'
      autoload :TargetInspectionResult,    'cocoapods/installer/analyzer/target_inspection_result'
      autoload :TargetInspector,           'cocoapods/installer/analyzer/target_inspector'

      # @return [String] The version of iOS which requires binaries with only 64-bit architectures
      #
      IOS_64_BIT_ONLY_VERSION = Version.new('11.0')

      # @return [Integer] The Xcode object version until which 64-bit architectures should be manually specified
      #
      # Xcode 10 will automatically select the correct architectures based on deployment target
      IOS_64_BIT_ONLY_PROJECT_VERSION = 50

      # @return [Sandbox] The sandbox to use for this analysis.
      #
      attr_reader :sandbox

      # @return [Podfile] The Podfile specification that contains the information of the Pods that should be installed.
      #
      attr_reader :podfile

      # @return [Lockfile] The Lockfile, if available, that stores the information about the Pods previously installed.
      #
      attr_reader :lockfile

      # @return [Array<Source>] Sources provided by plugins or `nil`.
      #
      attr_reader :plugin_sources

      # @return [Bool] Whether the analysis has dependencies and thus sources must be configured.
      #
      # @note   This is used by the `pod lib lint` command to prevent update of specs when not needed.
      #
      attr_reader :has_dependencies
      alias_method :has_dependencies?, :has_dependencies

      # @return [Hash, Boolean, nil] Pods that have been requested to be updated or true if all Pods should be updated.
      #         This can be false if no pods should be updated.
      #
      attr_reader :pods_to_update

      # Initialize a new instance
      #
      # @param  [Sandbox] sandbox @see #sandbox
      # @param  [Podfile] podfile @see #podfile
      # @param  [Lockfile] lockfile @see #lockfile
      # @param  [Array<Source>] plugin_sources @see #plugin_sources
      # @param  [Boolean] has_dependencies @see #has_dependencies
      # @param  [Hash, Boolean, nil] pods_to_update @see #pods_to_update
      #
      def initialize(sandbox, podfile, lockfile = nil, plugin_sources = nil, has_dependencies = true,
                     pods_to_update = false)
        @sandbox  = sandbox
        @podfile  = podfile
        @lockfile = lockfile
        @plugin_sources = plugin_sources
        @has_dependencies = has_dependencies
        @pods_to_update = pods_to_update
        @podfile_dependency_cache = PodfileDependencyCache.from_podfile(podfile)
        @result = nil
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
        return @result if @result
        validate_podfile!
        validate_lockfile_version!
        if installation_options.integrate_targets?
          target_inspections = inspect_targets_to_integrate
        else
          verify_platforms_specified!
          target_inspections = {}
        end
        podfile_state = generate_podfile_state

        store_existing_checkout_options
        if allow_fetches == :outdated
          # special-cased -- we're only really resolving for outdated, rather than doing a full analysis
        elsif allow_fetches == true
          fetch_external_sources(podfile_state)
        elsif !dependencies_to_fetch(podfile_state).all?(&:local?)
          raise Informative, 'Cannot analyze without fetching dependencies since the sandbox is not up-to-date. Run `pod install` to ensure all dependencies have been fetched.' \
            "\n    The missing dependencies are:\n    \t#{dependencies_to_fetch(podfile_state).reject(&:local?).join("\n    \t")}"
        end

        locked_dependencies = generate_version_locking_dependencies(podfile_state)
        resolver_specs_by_target = resolve_dependencies(locked_dependencies)
        validate_platforms(resolver_specs_by_target)
        specifications  = generate_specifications(resolver_specs_by_target)
        targets         = generate_targets(resolver_specs_by_target, target_inspections)
        pod_targets     = calculate_pod_targets(targets)
        sandbox_state   = generate_sandbox_state(specifications)
        specs_by_target = resolver_specs_by_target.each_with_object({}) do |rspecs_by_target, hash|
          hash[rspecs_by_target[0]] = rspecs_by_target[1].map(&:spec)
        end
        specs_by_source = Hash[resolver_specs_by_target.values.flatten(1).group_by(&:source).map do |source, specs|
          [source, specs.map(&:spec).uniq]
        end]
        sources.each { |s| specs_by_source[s] ||= [] }
        @result = AnalysisResult.new(podfile_state, specs_by_target, specs_by_source, specifications, sandbox_state,
                                     targets, pod_targets, @podfile_dependency_cache)
      end

      # Updates the git source repositories.
      #
      def update_repositories
        sources.each do |source|
          if source.git?
            config.sources_manager.update(source.name, true)
          else
            UI.message "Skipping `#{source.name}` update because the repository is not a git source repository."
          end
        end
        @specs_updated = true
      end

      # Returns the sources used to query for specifications.
      #
      # When no explicit Podfile sources or plugin sources are defined, this defaults to the master spec repository.
      #
      # @return [Array<Source>] the sources to be used in finding specifications, as specified by the podfile or all
      #         sources.
      #
      def sources
        @sources ||= begin
          sources = podfile.sources
          plugin_sources = @plugin_sources || []

          # Add any sources specified using the :source flag on individual dependencies.
          dependency_sources = podfile_dependencies.map(&:podspec_repo).compact
          all_dependencies_have_sources = dependency_sources.count == podfile_dependencies.count

          if all_dependencies_have_sources
            sources = dependency_sources
          elsif has_dependencies? && sources.empty? && plugin_sources.empty?
            sources = ['https://github.com/CocoaPods/Specs.git']
          else
            sources += dependency_sources
          end

          result = sources.uniq.map do |source_url|
            config.sources_manager.find_or_create_source_with_url(source_url)
          end
          unless plugin_sources.empty?
            result.insert(0, *plugin_sources)
          end
          result
        end
      end

      #-----------------------------------------------------------------------#

      private

      # @!group Configuration

      # @return [Bool] Whether the version of the dependencies which did not
      #         change in the Podfile should be locked.
      #
      def update_mode?
        pods_to_update != nil
      end

      # @return [Symbol] Whether and how the dependencies in the Podfile
      #                  should be updated.
      #
      def update_mode
        if !pods_to_update
          :none
        elsif pods_to_update == true
          :all
        elsif !pods_to_update[:pods].nil?
          :selected
        end
      end

      def podfile_dependencies
        @podfile_dependency_cache.podfile_dependencies
      end

      #-----------------------------------------------------------------------#

      def validate_podfile!
        validator = Installer::PodfileValidator.new(podfile, @podfile_dependency_cache)
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
      # @return [SpecState]
      #
      def generate_podfile_state
        if lockfile
          pods_state = nil
          UI.section 'Finding Podfile changes' do
            pods_by_state = lockfile.detect_changes_with_podfile(podfile)
            pods_state = SpecsState.new(pods_by_state)
            pods_state.print if config.verbose?
          end
          pods_state
        else
          state = SpecsState.new
          state.added.merge(podfile_dependencies.map(&:root_name))
          state
        end
      end

      # Copies the pod targets of any of the app embedded aggregate targets into
      # their potential host aggregate target, if that potential host aggregate target's
      # user_target hosts any of the app embedded aggregate targets' user_targets
      #
      # @param  [AggregateTarget] aggregate_target the aggregate target whose user_target
      #         might host one or more of the embedded aggregate targets' user_targets
      #
      # @param  [Array<AggregateTarget>] embedded_aggregate_targets the aggregate targets
      #         representing the embedded targets to be integrated
      #
      # @param  [Boolean] libraries_only if true, only library-type embedded
      #         targets are considered, otherwise, all other types are have
      #         their pods copied to their host targets as well (extensions, etc.)
      #
      # @return [Hash{String=>Array<PodTarget>}] the additional pod targets to include to the host
      #          keyed by their configuration.
      #
      def embedded_target_pod_targets_by_host(aggregate_target, embedded_aggregate_targets, libraries_only)
        return {} if aggregate_target.requires_host_target?
        aggregate_user_target_uuids = Set.new(aggregate_target.user_targets.map(&:uuid))
        embedded_pod_targets_by_build_config = Hash.new([].freeze)
        embedded_aggregate_targets.each do |embedded_aggregate_target|
          # Skip non libraries in library-only mode
          next if libraries_only && !embedded_aggregate_target.library?
          next if aggregate_target.search_paths_aggregate_targets.include?(embedded_aggregate_target)
          next unless embedded_aggregate_target.user_targets.any? do |embedded_user_target|
            # You have to ask the host target's project for the host targets of
            # the embedded target, as opposed to asking user_project for the
            # embedded targets of the host target. The latter doesn't work when
            # the embedded target lives in a sub-project. The lines below get
            # the host target uuids for the embedded target and checks to see if
            # those match to any of the user_target uuids in the aggregate_target.
            host_target_uuids = Set.new(aggregate_target.user_project.host_targets_for_embedded_target(embedded_user_target).map(&:uuid))
            !aggregate_user_target_uuids.intersection(host_target_uuids).empty?
          end
          embedded_aggregate_target.user_build_configurations.keys.each do |configuration_name|
            pod_target_names = Set.new(aggregate_target.pod_targets_for_build_configuration(configuration_name).map(&:name))
            embedded_pod_targets = embedded_aggregate_target.pod_targets_for_build_configuration(configuration_name).select do |pod_target|
              if !pod_target_names.include?(pod_target.name) &&
                 aggregate_target.pod_targets.none? { |aggregate_pod_target| (pod_target.specs - aggregate_pod_target.specs).empty? }
                pod_target.name
              end
            end
            embedded_pod_targets_by_build_config[configuration_name] = embedded_pod_targets
          end
        end
        embedded_pod_targets_by_build_config
      end

      # Raises an error if there are embedded targets in the Podfile, but
      # their host targets have not been declared in the Podfile. As it
      # finds host targets, it collection information on host target types.
      #
      # @param  [Array<AggregateTarget>] aggregate_targets the generated
      #         aggregate targets
      #
      # @param  [Array<AggregateTarget>] embedded_aggregate_targets the aggregate targets
      #         representing the embedded targets to be integrated
      #
      def analyze_host_targets_in_podfile(aggregate_targets, embedded_aggregate_targets)
        target_definitions_by_uuid = {}
        # Collect aggregate target definitions by uuid to later lookup host target
        # definitions and verify their compatiblity with their embedded targets
        aggregate_targets.each do |target|
          target.user_targets.map(&:uuid).each do |uuid|
            target_definitions_by_uuid[uuid] = target.target_definition
          end
        end
        aggregate_target_user_projects = aggregate_targets.map(&:user_project)
        embedded_targets_missing_hosts = []
        host_uuid_to_embedded_target_definitions = {}
        # Search all of the known user projects for each embedded target's hosts
        embedded_aggregate_targets.each do |target|
          host_uuids = []
          aggregate_target_user_projects.product(target.user_targets).each do |user_project, user_target|
            host_uuids += user_project.host_targets_for_embedded_target(user_target).map(&:uuid)
          end
          # For each host, keep track of its embedded target definitions
          # to later verify each embedded target's compatiblity with its host,
          # ignoring the hosts that aren't known to CocoaPods (no target
          # definitions in the Podfile)
          host_uuids.each do |uuid|
            (host_uuid_to_embedded_target_definitions[uuid] ||= []) << target.target_definition if target_definitions_by_uuid.key? uuid
          end
          # If none of the hosts are known to CocoaPods (no target definitions
          # in the Podfile), add it to the list of targets missing hosts
          embedded_targets_missing_hosts << target unless host_uuids.any? do |uuid|
            target_definitions_by_uuid.key? uuid
          end
        end

        unless embedded_targets_missing_hosts.empty?
          embedded_targets_missing_hosts_product_types = Set.new embedded_targets_missing_hosts.flat_map(&:user_targets).map(&:symbol_type)
          target_names = embedded_targets_missing_hosts.map do |target|
            target.name.sub('Pods-', '') # Make the target names more recognizable to the user
          end.join ', '
          #  If the targets missing hosts are only frameworks, then this is likely
          #  a project for doing framework development. In that case, just warn that
          #  the frameworks that these targets depend on won't be integrated anywhere
          if embedded_targets_missing_hosts_product_types.subset?(Set.new([:framework, :static_library]))
            UI.warn "The Podfile contains framework or static library targets (#{target_names}), for which the Podfile does not contain host targets (targets which embed the framework)." \
              "\n" \
              'If this project is for doing framework development, you can ignore this message. Otherwise, add a target to the Podfile that embeds these frameworks to make this message go away (e.g. a test target).'
          else
            raise Informative, "Unable to find host target(s) for #{target_names}. Please add the host targets for the embedded targets to the Podfile." \
                                "\n" \
                                'Certain kinds of targets require a host target. A host target is a "parent" target which embeds a "child" target. These are example types of targets that need a host target:' \
                                "\n- Framework" \
                                "\n- App Extension" \
                                "\n- Watch OS 1 Extension" \
                                "\n- Messages Extension (except when used with a Messages Application)"
          end
        end

        target_mismatches = []
        host_uuid_to_embedded_target_definitions.each do |uuid, target_definitions|
          host_target_definition = target_definitions_by_uuid[uuid]
          target_definitions.each do |target_definition|
            unless host_target_definition.uses_frameworks? == target_definition.uses_frameworks?
              target_mismatches << "- #{host_target_definition.name} (#{host_target_definition.uses_frameworks?}) and #{target_definition.name} (#{target_definition.uses_frameworks?}) do not both set use_frameworks!."
            end
          end
        end

        unless target_mismatches.empty?
          heading = 'Unable to integrate the following embedded targets with their respective host targets (a host target is a "parent" target which embeds a "child" target like a framework or extension):'
          raise Informative, heading + "\n\n" + target_mismatches.sort.uniq.join("\n")
        end
      end

      # Creates the models that represent the targets generated by CocoaPods.
      #
      # @param  [Hash{Podfile::TargetDefinition => Array<ResolvedSpecification>}] resolver_specs_by_target
      #         mapping of targets to resolved specs (containing information about test usage)
      #         aggregate targets
      #
      # @param  [Array<TargetInspection>] target_inspections
      #         the user target inspections used to construct the aggregate and pod targets.
      #
      # @return [Array<AggregateTarget>] the list of aggregate targets generated.
      #
      def generate_targets(resolver_specs_by_target, target_inspections)
        resolver_specs_by_target = resolver_specs_by_target.reject { |td, _| td.abstract? }
        pod_targets = generate_pod_targets(resolver_specs_by_target, target_inspections)
        aggregate_targets = resolver_specs_by_target.keys.map do |target_definition|
          generate_target(target_definition, target_inspections, pod_targets, resolver_specs_by_target)
        end
        aggregate_targets.each do |target|
          search_paths_aggregate_targets = aggregate_targets.select do |aggregate_target|
            target.target_definition.targets_to_inherit_search_paths.include?(aggregate_target.target_definition)
          end
          target.search_paths_aggregate_targets.concat(search_paths_aggregate_targets).freeze
        end
        if installation_options.integrate_targets?
          # Copy embedded target pods that cannot have their pods embedded as frameworks to
          # their host targets, and ensure we properly link library pods to their host targets
          embedded_targets = aggregate_targets.select(&:requires_host_target?)
          analyze_host_targets_in_podfile(aggregate_targets, embedded_targets)

          use_frameworks_embedded_targets, non_use_frameworks_embedded_targets = embedded_targets.partition(&:requires_frameworks?)
          aggregate_targets = aggregate_targets.map do |aggregate_target|
            # For targets that require frameworks, we always have to copy their pods to their
            # host targets because those frameworks will all be loaded from the host target's bundle
            embedded_pod_targets = embedded_target_pod_targets_by_host(aggregate_target, use_frameworks_embedded_targets, false)

            # For targets that don't require frameworks, we only have to consider library-type
            # targets because their host targets will still need to link their pods
            embedded_pod_targets.merge!(embedded_target_pod_targets_by_host(aggregate_target, non_use_frameworks_embedded_targets, true))

            next aggregate_target if embedded_pod_targets.empty?
            aggregate_target.merge_embedded_pod_targets(embedded_pod_targets)
          end
        end
        aggregate_targets
      end

      # Setup the aggregate target for a single user target
      #
      # @param  [TargetDefinition] target_definition
      #         the target definition for the user target.
      #
      # @param  [Hash{TargetDefinition => TargetInspectionResult}] target_inspections
      #         the user target inspections used to construct the aggregate and pod targets.
      #
      # @param  [Array<PodTarget>] pod_targets
      #         the pod targets, which were generated.
      #
      # @param  [Hash{Podfile::TargetDefinition => Array<ResolvedSpecification>}] resolver_specs_by_target
      #         the resolved specifications grouped by target.
      #
      # @return [AggregateTarget]
      #
      def generate_target(target_definition, target_inspections, pod_targets, resolver_specs_by_target)
        if installation_options.integrate_targets?
          target_inspection = target_inspections[target_definition]
          raise "missing inspection: #{target_definition.name}" unless target_inspection
          target_requires_64_bit = Analyzer.requires_64_bit_archs?(target_definition.platform, target_inspection.project.object_version)
          user_project = target_inspection.project
          client_root = target_inspection.client_root
          user_target_uuids = target_inspection.project_target_uuids
          user_build_configurations = target_inspection.build_configurations
          archs = target_requires_64_bit ? ['$(ARCHS_STANDARD_64_BIT)'] : target_inspection.archs
        else
          target_requires_64_bit = Analyzer.requires_64_bit_archs?(target_definition.platform, nil)
          user_project = nil
          client_root = config.installation_root.realpath
          user_target_uuids = []
          user_build_configurations = target_definition.build_configurations || Target::DEFAULT_BUILD_CONFIGURATIONS
          archs = target_requires_64_bit ? ['$(ARCHS_STANDARD_64_BIT)'] : []
        end
        platform = target_definition.platform
        build_configurations = user_build_configurations.keys.concat(target_definition.all_whitelisted_configurations).uniq
        pod_targets_for_build_configuration = filter_pod_targets_for_target_definition(target_definition, pod_targets,
                                                                                       resolver_specs_by_target,
                                                                                       build_configurations)
        AggregateTarget.new(sandbox, target_definition.uses_frameworks?, user_build_configurations, archs, platform,
                            target_definition, client_root, user_project, user_target_uuids,
                            pod_targets_for_build_configuration)
      end

      # @return [Array<PodTarget>] The model representations of pod targets.
      #
      def calculate_pod_targets(aggregate_targets)
        aggregate_target_pod_targets = aggregate_targets.flat_map(&:pod_targets).uniq
        test_dependent_targets = aggregate_target_pod_targets.flat_map do |pod_target|
          pod_target.test_specs.flat_map do |test_spec|
            pod_target.recursive_test_dependent_targets(test_spec)
          end
        end
        (aggregate_target_pod_targets + test_dependent_targets).uniq
      end

      # Returns a filtered list of pod targets that should or should not be part of the target definition. Pod targets
      # used by tests only are filtered.
      #
      # @param [TargetDefinition] target_definition
      #        the target definition to use as the base for filtering
      #
      # @param [Array<PodTarget>] pod_targets
      #        the array of pod targets to check against
      #
      # @param  [Hash{Podfile::TargetDefinition => Array<ResolvedSpecification>}] resolver_specs_by_target
      #         the resolved specifications grouped by target.
      #
      # @param  [Array<String>] build_configurations
      #         The list of all build configurations the targets will be built for.
      #
      # @return [Hash<String => Array<PodTarget>>]
      #         the filtered list of pod targets, grouped by build configuration.
      #
      def filter_pod_targets_for_target_definition(target_definition, pod_targets, resolver_specs_by_target, build_configurations)
        pod_targets_by_build_config = Hash.new([].freeze)
        build_configurations.each { |config| pod_targets_by_build_config[config] = [] }

        pod_targets.each do |pod_target|
          next unless pod_target.target_definitions.include?(target_definition)
          next unless resolver_specs_by_target[target_definition].any? do |resolver_spec|
            !resolver_spec.used_by_tests_only? && pod_target.specs.include?(resolver_spec.spec)
          end

          pod_name = pod_target.pod_name

          dependencies = @podfile_dependency_cache.target_definition_dependencies(target_definition).select do |dependency|
            Specification.root_name(dependency.name) == pod_name
          end

          build_configurations.each do |configuration_name|
            whitelists = dependencies.map do |dependency|
              target_definition.pod_whitelisted_for_configuration?(dependency.name, configuration_name)
            end.uniq

            case whitelists
            when [], [true] then nil
            when [false] then next
            else
              raise Informative, "The subspecs of `#{pod_name}` are linked to " \
                "different build configurations for the `#{target_definition}` " \
                'target. CocoaPods does not currently support subspecs across ' \
                'different build configurations.'
            end

            pod_targets_by_build_config[configuration_name] << pod_target
          end
        end

        pod_targets_by_build_config
      end

      # Setup the pod targets for an aggregate target. Deduplicates resulting
      # targets by grouping by platform and subspec by their root
      # to create a {PodTarget} for each spec.
      #
      # @param  [Hash{Podfile::TargetDefinition => Array<ResolvedSpecification>}] resolver_specs_by_target
      #         the resolved specifications grouped by target.
      #
      # @param  [Hash{TargetDefinition => TargetInspectionResult}] target_inspections
      #         the user target inspections used to construct the aggregate and pod targets.
      #
      # @return [Array<PodTarget>]
      #
      def generate_pod_targets(resolver_specs_by_target, target_inspections)
        if installation_options.deduplicate_targets?
          distinct_targets = resolver_specs_by_target.each_with_object({}) do |dependency, hash|
            target_definition, dependent_specs = *dependency
            dependent_specs.group_by(&:root).each do |root_spec, resolver_specs|
              all_specs = resolver_specs.map(&:spec)
              test_specs, specs = all_specs.partition(&:test_specification?)
              pod_variant = PodVariant.new(specs, test_specs, target_definition.platform, target_definition.uses_frameworks?)
              hash[root_spec] ||= {}
              (hash[root_spec][pod_variant] ||= []) << target_definition
              hash[root_spec].keys.find { |k| k == pod_variant }.test_specs.concat(test_specs).uniq!
            end
          end

          pod_targets = distinct_targets.flat_map do |_root, target_definitions_by_variant|
            suffixes = PodVariantSet.new(target_definitions_by_variant.keys).scope_suffixes
            target_definitions_by_variant.flat_map do |variant, target_definitions|
              generate_pod_target(target_definitions, target_inspections, variant.specs + variant.test_specs, :scope_suffix => suffixes[variant])
            end
          end

          all_resolver_specs = resolver_specs_by_target.values.flatten.map(&:spec).uniq
          pod_targets_by_name = pod_targets.group_by(&:pod_name).each_with_object({}) do |(name, values), hash|
            # Sort the target by the number of activated subspecs, so that
            # we prefer a minimal target as transitive dependency.
            hash[name] = values.sort_by { |pt| pt.specs.count }
          end
          pod_targets.each do |target|
            all_specs = all_resolver_specs.group_by(&:name)
            dependencies = dependencies_for_specs(target.non_test_specs.to_set, target.platform, all_specs.dup).group_by(&:root)
            target.dependent_targets = filter_dependencies(dependencies, pod_targets_by_name, target)
            target.test_dependent_targets_by_spec_name = target.test_specs.each_with_object({}) do |test_spec, hash|
              test_dependencies = dependencies_for_specs([test_spec], target.platform, all_specs).group_by(&:root)
              test_dependencies.delete_if { |k| dependencies.key? k }
              hash[test_spec.name] = filter_dependencies(test_dependencies, pod_targets_by_name, target)
            end
          end
        else
          dedupe_cache = {}
          resolver_specs_by_target.flat_map do |target_definition, specs|
            grouped_specs = specs.group_by(&:root).values.uniq
            pod_targets = grouped_specs.flat_map do |pod_specs|
              generate_pod_target([target_definition], target_inspections, pod_specs.map(&:spec)).scoped(dedupe_cache)
            end

            pod_targets.each do |target|
              all_specs = specs.map(&:spec).group_by(&:name)
              dependencies = dependencies_for_specs(target.non_test_specs.to_set, target.platform, all_specs.dup).group_by(&:root)
              target.dependent_targets = pod_targets.reject { |t| dependencies[t.root_spec].nil? }
              target.test_dependent_targets_by_spec_name = target.test_specs.each_with_object({}) do |test_spec, hash|
                test_dependencies = dependencies_for_specs(target.test_specs.to_set, target.platform, all_specs.dup).group_by(&:root)
                test_dependencies.delete_if { |k| dependencies.key? k }
                hash[test_spec.name] = pod_targets.reject { |t| test_dependencies[t.root_spec].nil? }
              end
            end
          end
        end
      end

      def filter_dependencies(dependencies, pod_targets_by_name, target)
        dependencies.map do |root_spec, deps|
          pod_targets_by_name[root_spec.name].find do |t|
            next false if t.platform.symbolic_name != target.platform.symbolic_name ||
                t.requires_frameworks? != target.requires_frameworks?
            spec_names = t.specs.map(&:name)
            deps.all? { |dep| spec_names.include?(dep.name) }
          end
        end
      end

      # Returns the specs upon which the given specs _directly_ depend.
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
      # @param  [Hash<String, Specification>] all_specs
      #         All specifications which are installed alongside.
      #
      # @return [Array<Specification>]
      #
      def dependencies_for_specs(specs, platform, all_specs)
        return [] if specs.empty? || all_specs.empty?

        dependent_specs = Set.new

        specs.each do |s|
          s.dependencies(platform).each do |dep|
            all_specs[dep.name].each do |spec|
              dependent_specs << spec
            end
          end
        end

        dependent_specs - specs
      end

      # Create a target for each spec group
      #
      # @param  [Array<TargetDefinition>] target_definitions
      #         the target definitions of the aggregate target
      #
      # @param  [Hash{TargetDefinition => TargetInspectionResult}] target_inspections
      #         the user target inspections used to construct the aggregate and pod targets.
      #
      # @param  [Array<Specification>] specs
      #         the specifications of an equal root.
      #
      # @param  [String] scope_suffix
      #         @see PodTarget#scope_suffix
      #
      # @return [PodTarget]
      #
      def generate_pod_target(target_definitions, target_inspections, specs, scope_suffix: nil)
        object_version = target_inspections.values.map { |ti| ti.project.object_version }.min
        target_requires_64_bit = target_definitions.all? { |td| Analyzer.requires_64_bit_archs?(td.platform, object_version) }
        if installation_options.integrate_targets?
          target_inspections = target_inspections.select { |t, _| target_definitions.include?(t) }.values
          user_build_configurations = target_inspections.map(&:build_configurations).reduce({}, &:merge)
          archs = if target_requires_64_bit
                    ['$(ARCHS_STANDARD_64_BIT)']
                  else
                    target_inspections.flat_map(&:archs).compact.uniq.sort
                  end
        else
          user_build_configurations = {}
          archs = target_requires_64_bit ? ['$(ARCHS_STANDARD_64_BIT)'] : []
        end
        host_requires_frameworks = target_definitions.any?(&:uses_frameworks?)
        platform = determine_platform(specs, target_definitions, host_requires_frameworks)
        file_accessors = create_file_accessors(specs, platform)
        PodTarget.new(sandbox, host_requires_frameworks, user_build_configurations, archs, platform, specs,
                      target_definitions, file_accessors, scope_suffix)
      end

      # Creates the file accessors for a given pod.
      #
      # @param [Array<Specification>] specs
      #        the specs to map each file accessor to.
      #
      # @param [Platform] platform
      #        the platform to use when generating each file accessor.
      #
      # @return [Array<FileAccessor>]
      #
      def create_file_accessors(specs, platform)
        name = specs.first.name
        pod_root = sandbox.pod_dir(name)
        path_list = Sandbox::PathList.new(pod_root)
        specs.map do |spec|
          Sandbox::FileAccessor.new(path_list, spec.consumer(platform))
        end
      end

      # Calculates and returns the platform to use for the given list of specs and target definitions.
      #
      # @param [Array<Specification>] specs
      #        the specs to inspect and calculate the platform for.
      #
      # @param [Array<TargetDefinition>] target_definitions
      #        the target definitions these specs are part of.
      #
      # @param [Boolean] host_requires_frameworks
      #        whether the platform is calculated for a target that needs to be packaged as a framework.
      #
      # @return [Platform]
      #
      def determine_platform(specs, target_definitions, host_requires_frameworks)
        platform_name = target_definitions.first.platform.name
        default = Podfile::TargetDefinition::PLATFORM_DEFAULTS[platform_name]
        deployment_target = specs.map do |spec|
          Version.new(spec.deployment_target(platform_name) || default)
        end.max
        if platform_name == :ios && host_requires_frameworks
          minimum = Version.new('8.0')
          deployment_target = [deployment_target, minimum].max
        end
        Platform.new(platform_name, deployment_target)
      end

      # Generates dependencies that require the specific version of the Pods
      # that haven't changed in the {Lockfile}.
      #
      # These dependencies are passed to the {Resolver}, unless the installer
      # is in update mode, to prevent it from upgrading the Pods that weren't
      # changed in the {Podfile}.
      #
      # @param [SpecState] podfile_state
      #        the state of the podfile for which dependencies have or have not changed, added, deleted or updated.
      #
      # @return [Molinillo::DependencyGraph<Dependency>] the dependencies
      #         generated by the lockfile that prevent the resolver to update
      #         a Pod.
      #
      def generate_version_locking_dependencies(podfile_state)
        if update_mode == :all || !lockfile
          LockingDependencyAnalyzer.unlocked_dependency_graph
        else
          deleted_and_changed = podfile_state.changed + podfile_state.deleted
          deleted_and_changed += pods_to_update[:pods] if update_mode == :selected
          local_pod_names = podfile_dependencies.select(&:local?).map(&:root_name)
          pods_to_unlock = local_pod_names.to_set.delete_if do |pod_name|
            next unless sandbox_specification = sandbox.specification(pod_name)
            sandbox_specification.checksum == lockfile.checksum(pod_name)
          end
          LockingDependencyAnalyzer.generate_version_locking_dependencies(lockfile, deleted_and_changed, pods_to_unlock)
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
      # @param [SpecState] podfile_state
      #        the state of the podfile for which dependencies have or have not changed, added, deleted or updated.
      #
      # @return [void]
      #
      def fetch_external_sources(podfile_state)
        verify_no_pods_with_different_sources!
        deps = dependencies_to_fetch(podfile_state)
        pods = pods_to_fetch(podfile_state)
        return if deps.empty?
        UI.section 'Fetching external sources' do
          deps.sort.each do |dependency|
            fetch_external_source(dependency, !pods.include?(dependency.root_name))
          end
        end
      end

      def verify_no_pods_with_different_sources!
        deps_with_different_sources = podfile_dependencies.group_by(&:root_name).
          select { |_root_name, dependencies| dependencies.map(&:external_source).uniq.count > 1 }
        deps_with_different_sources.each do |root_name, dependencies|
          raise Informative, 'There are multiple dependencies with different ' \
          "sources for `#{root_name}` in #{UI.path podfile.defined_in_file}:" \
          "\n\n- #{dependencies.map(&:to_s).join("\n- ")}"
        end
      end

      def fetch_external_source(dependency, use_lockfile_options)
        source = if use_lockfile_options && lockfile && checkout_options = lockfile.checkout_options_for_pod_named(dependency.root_name)
                   ExternalSources.from_params(checkout_options, dependency, podfile.defined_in_file, installation_options.clean?)
                 else
                   ExternalSources.from_dependency(dependency, podfile.defined_in_file, installation_options.clean?)
                 end
        source.fetch(sandbox)
      end

      def dependencies_to_fetch(podfile_state)
        @deps_to_fetch ||= begin
          deps_to_fetch = []
          deps_with_external_source = podfile_dependencies.select(&:external_source)

          if update_mode == :all
            deps_to_fetch = deps_with_external_source
          else
            deps_to_fetch = deps_with_external_source.select { |dep| pods_to_fetch(podfile_state).include?(dep.root_name) }
            deps_to_fetch_if_needed = deps_with_external_source.select { |dep| podfile_state.unchanged.include?(dep.root_name) }
            deps_to_fetch += deps_to_fetch_if_needed.select do |dep|
              sandbox.specification_path(dep.root_name).nil? ||
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

      def pods_to_fetch(podfile_state)
        @pods_to_fetch ||= begin
          pods_to_fetch = podfile_state.added + podfile_state.changed
          if update_mode == :selected
            pods_to_fetch += pods_to_update[:pods]
          elsif update_mode == :all
            pods_to_fetch += podfile_state.unchanged + podfile_state.deleted
          end
          pods_to_fetch += podfile_dependencies.
            select { |dep| Hash(dep.external_source).key?(:podspec) && sandbox.specification_path(dep.root_name).nil? }.
            map(&:root_name)
          pods_to_fetch
        end
      end

      def store_existing_checkout_options
        podfile_dependencies.select(&:external_source).each do |dep|
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
      def resolve_dependencies(locked_dependencies)
        duplicate_dependencies = podfile_dependencies.group_by(&:name).
          select { |_name, dependencies| dependencies.count > 1 }
        duplicate_dependencies.each do |name, dependencies|
          UI.warn "There are duplicate dependencies on `#{name}` in #{UI.path podfile.defined_in_file}:\n\n" \
           "- #{dependencies.map(&:to_s).join("\n- ")}"
        end

        resolver_specs_by_target = nil
        UI.section "Resolving dependencies of #{UI.path(podfile.defined_in_file) || 'Podfile'}" do
          resolver = Pod::Resolver.new(sandbox, podfile, locked_dependencies, sources, @specs_updated)
          resolver_specs_by_target = resolver.resolve
          resolver_specs_by_target.values.flatten(1).map(&:spec).each(&:validate_cocoapods_version)
        end
        resolver_specs_by_target
      end

      # Warns for any specification that is incompatible with its target.
      #
      # @param  [Hash{TargetDefinition => Array<Spec>}] resolver_specs_by_target
      #         the resolved specifications grouped by target.
      #
      # @return [Hash{TargetDefinition => Array<Spec>}] the specifications
      #         grouped by target.
      #
      def validate_platforms(resolver_specs_by_target)
        resolver_specs_by_target.each do |target, specs|
          specs.map(&:spec).each do |spec|
            next unless target_platform = target.platform
            unless spec.available_platforms.any? { |p| target_platform.supports?(p) }
              UI.warn "The platform of the target `#{target.name}` "     \
                "(#{target.platform}) may not be compatible with `#{spec}` which has "  \
                "a minimum requirement of #{spec.available_platforms.join(' - ')}."
            end
          end
        end
      end

      # Returns the list of all the resolved specifications.
      #
      # @param  [Hash{TargetDefinition => Array<Spec>}] resolver_specs_by_target
      #         the resolved specifications grouped by target.
      #
      # @return [Array<Specification>] the list of the specifications.
      #
      def generate_specifications(resolver_specs_by_target)
        resolver_specs_by_target.values.flatten.map(&:spec).uniq
      end

      # Computes the state of the sandbox respect to the resolved
      # specifications.
      #
      # @return [SpecsState] the representation of the state of the manifest
      #         specifications.
      #
      def generate_sandbox_state(specifications)
        sandbox_state = nil
        UI.section 'Comparing resolved specification to the sandbox manifest' do
          sandbox_analyzer = SandboxAnalyzer.new(sandbox, specifications, update_mode?)
          sandbox_state = sandbox_analyzer.analyze
          sandbox_state.print
        end
        sandbox_state
      end

      class << self
        # @param  [Platform] platform
        #         The platform to build against
        #
        # @param  [String, Nil] object_version
        #         The user project's object version, or nil if not available
        #
        # @return [Boolean] Whether the platform requires 64-bit architectures
        #
        def requires_64_bit_archs?(platform, object_version)
          return false unless platform
          case platform.name
          when :osx
            true
          when :ios
            if (version = object_version)
              platform.deployment_target >= IOS_64_BIT_ONLY_VERSION && version.to_i < IOS_64_BIT_ONLY_PROJECT_VERSION
            else
              platform.deployment_target >= IOS_64_BIT_ONLY_VERSION
            end
          when :watchos
            false
          when :tvos
            false
          end
        end
      end

      #-----------------------------------------------------------------------#

      # @!group Analysis sub-steps

      # Checks whether the platform is specified if not integrating
      #
      # @return [void]
      #
      def verify_platforms_specified!
        unless installation_options.integrate_targets?
          @podfile_dependency_cache.target_definition_list.each do |target_definition|
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
          inspectors = @podfile_dependency_cache.target_definition_list.map do |target_definition|
            next if target_definition.abstract?
            TargetInspector.new(target_definition, config.installation_root)
          end.compact
          inspectors.group_by(&:compute_project_path).each do |project_path, target_inspectors|
            project = Xcodeproj::Project.open(project_path)
            target_inspectors.each do |inspector|
              target_definition = inspector.target_definition
              results = inspector.compute_results(project)
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
