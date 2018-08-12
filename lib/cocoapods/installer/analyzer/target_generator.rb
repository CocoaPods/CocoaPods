module Pod
  class Installer
    class Analyzer
      class TargetGenerator
        # @return [String] The version of iOS which requires binaries with only 64-bit architectures
        #
        IOS_64_BIT_ONLY_VERSION = Version.new('11.0')

        # Creates aggregate targets for each of the target definitions
        #
        # @param  [Hash{TargetDefinition => Array<ResolverSpecification>}] resolver_specs_by_target
        #         mapping of targets to resolved specs (containing information about test usage)
        #
        # @param  [Hash{TargetDefinition => Array<TargetInspectionResult>}] target_inspections
        #         the user target inspections used to construct the aggregate and pod targets.
        #
        # @param  [PodfileDependencyCache] dependency_cache
        #         the podfile dependency cache
        #
        # @param  [Sandbox] sandbox
        #         the sandbox into which the targets will be installed
        #
        # @param  [InstallationOptions] installation_options
        #         the installation options to use when generating the targets
        #
        # @return [Array<AggregateTarget>] the list of aggregate targets generated.
        #
        def self.generate_aggregate_targets(resolver_specs_by_target, target_inspections, dependency_cache, sandbox, installation_options)
          resolver_specs_by_target = resolver_specs_by_target.reject { |td, _| td.abstract? }
          pod_targets = generate_pod_targets(resolver_specs_by_target, target_inspections, sandbox, installation_options)
          aggregate_targets = resolver_specs_by_target.map do |target_definition, resolver_specs|
            generate_aggregate_target(target_definition, target_inspections, pod_targets, resolver_specs, dependency_cache, sandbox, installation_options)
          end
          aggregate_targets.each do |target|
            search_paths_aggregate_targets = aggregate_targets.select do |aggregate_target|
              target.target_definition.targets_to_inherit_search_paths.include?(aggregate_target.target_definition)
            end
            target.search_paths_aggregate_targets.concat(search_paths_aggregate_targets).freeze
          end
          aggregate_targets
        end

        # Setup the pod targets for an aggregate target. Deduplicates resulting
        # targets by grouping by platform and subspec by their root
        # to create a {PodTarget} for each spec.
        #
        # @param  [Hash{TargetDefinition => Array<ResolverSpecification>}] resolver_specs_by_target
        #         the resolved specifications grouped by their target definition.
        #
        # @param  [Hash{TargetDefinition => Array<TargetInspectionResult>}] target_inspections
        #         the user target inspections used to construct the aggregate and pod targets.
        #
        # @param  [Sandbox] sandbox
        #         the sandbox into which the pod targets will be installed
        #
        # @param  [InstallationOptions] installation_options
        #         the installation options to use when generating the targets
        #
        # @return [Array<PodTarget>]
        #
        def self.generate_pod_targets(resolver_specs_by_target, target_inspections, sandbox, installation_options)
          if installation_options.deduplicate_targets?
            distinct_targets = resolver_specs_by_target.each_with_object({}) do |(target_definition, dependent_specs), hash|
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
                generate_pod_target(target_definitions, target_inspections, variant.specs + variant.test_specs, sandbox, installation_options, :scope_suffix => suffixes[variant])
              end
            end
          else
            dedupe_cache = {}
            pod_targets = resolver_specs_by_target.flat_map do |target_definition, specs|
              grouped_specs = specs.group_by(&:root).values.uniq
              grouped_specs.flat_map do |pod_specs|
                generate_pod_target([target_definition], target_inspections, pod_specs.map(&:spec), sandbox, installation_options).scoped(dedupe_cache)
              end
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
        end

        #-----------------------------------------------------------------------#

        class << self
          # @!group Target Generation Helpers

          private

          # Generate an aggregate target for a single user target
          #
          # @param  [TargetInspection] target_inspection
          #         the target inspection for the target definition
          #
          # @param  [Hash{TargetDefinition => Array<TargetInspectionResult>}] target_inspections
          #         the user target inspections used to construct the aggregate and pod targets.
          #
          # @param  [Array<PodTarget>] pod_targets
          #         the pod targets, which were generated.
          #
          # @param  [Array<ResolvedSpecification>}] resolver_specs
          #         the resolved for the target.
          #
          # @param  [PodfileDependencyCache] dependency_cache
          #         the podfile dependency cache
          #
          # @param  [Sandbox] sandbox
          #         the sandbox into which the targets will be installed
          #
          # @param  [InstallationOptions] installation_options
          #         the installation_options to use while generating the target
          #
          # @return [AggregateTarget]
          #
          def generate_aggregate_target(target_definition, target_inspections, pod_targets, resolver_specs, dependency_cache, sandbox, installation_options)
            target_requires_64_bit = requires_64_bit_archs?(target_definition.platform)
            if installation_options.integrate_targets?
              target_inspection = target_inspections[target_definition]
              raise "missing inspection: #{target_definition.name}" unless target_inspection
              user_project = target_inspection.project
              client_root = user_project.path.dirname.realpath
              user_target_uuids = target_inspection.project_target_uuids
              user_build_configurations = target_inspection.build_configurations
              archs = target_requires_64_bit ? ['$(ARCHS_STANDARD_64_BIT)'] : target_inspection.archs
            else
              user_project = nil
              client_root = Config.instance.installation_root
              user_target_uuids = []
              user_build_configurations = target_definition.build_configurations || Target::DEFAULT_BUILD_CONFIGURATIONS
              archs = target_requires_64_bit ? ['$(ARCHS_STANDARD_64_BIT)'] : []
            end
            platform = target_definition.platform
            build_configurations = user_build_configurations.keys.concat(target_definition.all_whitelisted_configurations).uniq
            pod_targets_for_build_configuration = filter_pod_targets_for_target_definition(target_definition,
                                                                                           pod_targets,
                                                                                           resolver_specs,
                                                                                           dependency_cache,
                                                                                           build_configurations)
            AggregateTarget.new(sandbox, target_definition.uses_frameworks?, user_build_configurations, archs, platform,
                                target_definition, client_root, user_project, user_target_uuids,
                                pod_targets_for_build_configuration)
          end

          # Create a target for each spec group
          #
          # @param  [Array<TargetDefinition>] target_definitions
          #         the target definitions of the aggregate target
          #
          # @param  [Hash{TargetDefinition => Array<TargetInspectionResult>}] target_inspections
          #         the user target inspections used to construct the aggregate and pod targets.
          #
          # @param  [Array<Specification>] specs
          #         the specifications of an equal root.
          #
          # @param  [InstallationOptions] installation_options
          #
          # @param  [String] scope_suffix
          #         @see PodTarget#scope_suffix
          #
          # @return [PodTarget]
          #
          def generate_pod_target(target_definitions, target_inspections, specs, sandbox, installation_options, scope_suffix: nil)
            target_requires_64_bit = target_definitions.all? { |td| requires_64_bit_archs?(td.platform) }
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
            file_accessors = create_file_accessors(specs, platform, sandbox)
            PodTarget.new(sandbox, host_requires_frameworks, user_build_configurations, archs, platform, specs,
                          target_definitions, file_accessors, scope_suffix)
          end

          #-----------------------------------------------------------------------#

          # @group Private helpers

          private

          # @param  [Platform] platform
          #         The platform to build against
          #
          # @return [Boolean] Whether the platform requires 64-bit architectures
          #
          def requires_64_bit_archs?(platform)
            return false unless platform
            case platform.name
            when :osx
              true
            when :ios
              platform.deployment_target >= IOS_64_BIT_ONLY_VERSION
            when :watchos
              false
            when :tvos
              false
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

          # Creates the file accessors for a given pod.
          #
          # @param [Array<Specification>] specs
          #        the specs to map each file accessor to.
          #
          # @param [Platform] platform
          #        the platform to use when generating each file accessor.
          #
          # @param [Sandbox] sandbox
          #        the sandbox to use when creating the file accessors
          #
          # @return [Array<FileAccessor>]
          #
          def create_file_accessors(specs, platform, sandbox)
            name = specs.first.name
            pod_root = sandbox.pod_dir(name)
            path_list = Sandbox::PathList.new(pod_root)
            specs.map do |spec|
              Sandbox::FileAccessor.new(path_list, spec.consumer(platform))
            end
          end

          # @param [Array<Hash<Specification, Array<Specification>>] dependencies
          #        The list of specifications and the specifications they depend on
          #
          # @param [Hash<String, Array<PodTarget>>] pod_targets_by_name
          #        Pod targets grouped by their Pod name
          #
          # @param [PodTarget] target
          #        The target by which to filter the dependencies
          #
          # @return [Array<PodTarget>] the dependencies of #target
          #
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
          # @param  [Hash<String, Array<Specification>>] all_specs
          #         All specifications which are installed alongside, grouped by their root name.
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

          # Returns a filtered list of pod targets that should or should not be part of the target definition. Pod targets
          # used by tests only are filtered.
          #
          # @param [TargetDefinition] target_definition
          #        the target definition to use as the base for filtering
          #
          # @param [Array<PodTarget>] pod_targets
          #        the array of pod targets to check against
          #
          # @param  [Array<ResolverSpecification>}] resolver_specs
          #         the resolved specifications for the target_inspection
          #
          # @param  [PodfileDependencyCache] dependency_cache
          #         the Podfile dependency cache
          #
          # @param  [Array<String>] build_configurations
          #         The list of all build configurations the targets will be built for.
          #
          # @return [Hash<String => Array<PodTarget>>]
          #         the filtered list of pod targets, grouped by build configuration.
          #
          def filter_pod_targets_for_target_definition(target_definition, pod_targets, resolver_specs, dependency_cache, build_configurations)
            pod_targets_by_build_config = Hash.new([].freeze)
            build_configurations.each { |config| pod_targets_by_build_config[config] = [] }

            pod_targets.each do |pod_target|
              next unless pod_target.target_definitions.include?(target_definition)
              next unless resolver_specs.any? do |resolver_spec|
                !resolver_spec.used_by_tests_only? && pod_target.specs.include?(resolver_spec.spec)
              end

              pod_name = pod_target.pod_name

              dependencies = dependency_cache.target_definition_dependencies(target_definition).select do |dependency|
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
        end
      end
    end
  end
end
