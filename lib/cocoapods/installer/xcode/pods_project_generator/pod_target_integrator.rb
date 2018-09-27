module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        # This class is responsible for integrating a pod target. This includes integrating
        # the test targets included by each pod target.
        #
        class PodTargetIntegrator
          # @return [TargetInstallationResult] the installation result of the target that should be integrated.
          #
          attr_reader :target_installation_result

          # @return [InstallationOptions] the installation options from the Podfile.
          #
          attr_reader :installation_options

          # Initialize a new instance
          #
          # @param  [TargetInstallationResult] target_installation_result @see #target_installation_result
          # @param  [InstallationOptions] installation_options @see #installation_options
          #
          def initialize(target_installation_result, installation_options)
            @target_installation_result = target_installation_result
            @installation_options = installation_options
          end

          # Integrates the pod target.
          #
          # @return [void]
          #
          def integrate!
            UI.section(integration_message) do
              target_installation_result.test_specs_by_native_target.each do |test_native_target, test_specs|
                test_specs.each do |test_spec|
                  add_embed_frameworks_script_phase(test_native_target, test_spec)
                  add_copy_resources_script_phase(test_native_target, test_spec)
                end
                UserProjectIntegrator::TargetIntegrator.create_or_update_user_script_phases(script_phases_for_specs(test_specs), test_native_target)
              end
              specs = target.non_test_specs
              UserProjectIntegrator::TargetIntegrator.create_or_update_user_script_phases(script_phases_for_specs(specs), target_installation_result.native_target)
            end
          end

          # @return [String] a string representation suitable for debugging.
          #
          def inspect
            "#<#{self.class} for target `#{target.label}'>"
          end

          private

          # @!group Integration steps
          #---------------------------------------------------------------------#

          # Find or create a 'Copy Pods Resources' build phase
          #
          # @return [void]
          #
          def add_copy_resources_script_phase(native_target, test_spec)
            script_path = "${PODS_ROOT}/#{target.copy_resources_script_path_for_test_spec(test_spec).relative_path_from(target.sandbox.root)}"
            input_paths = []
            output_paths = []
            unless installation_options.disable_input_output_paths?
              resource_paths = target.dependent_targets_for_test_spec(test_spec).flat_map do |dependent_target|
                spec_paths_to_include = dependent_target.non_test_specs.map(&:name)
                spec_paths_to_include << test_spec.name if dependent_target == target
                dependent_target.resource_paths.values_at(*spec_paths_to_include).flatten.compact
              end
              unless resource_paths.empty?
                resource_paths_flattened = resource_paths.flatten.uniq
                input_paths = [script_path, *resource_paths_flattened]
                output_paths = UserProjectIntegrator::TargetIntegrator.resource_output_paths(resource_paths_flattened)
              end
            end
            UserProjectIntegrator::TargetIntegrator.validate_input_output_path_limit(input_paths, output_paths)
            UserProjectIntegrator::TargetIntegrator.create_or_update_copy_resources_script_phase_to_target(native_target, script_path, input_paths, output_paths)
          end

          # Find or create a 'Embed Pods Frameworks' Copy Files Build Phase
          #
          # @return [void]
          #
          def add_embed_frameworks_script_phase(native_target, test_spec)
            script_path = "${PODS_ROOT}/#{target.embed_frameworks_script_path_for_test_spec(test_spec).relative_path_from(target.sandbox.root)}"
            input_paths = []
            output_paths = []
            unless installation_options.disable_input_output_paths?
              framework_paths = target.dependent_targets_for_test_spec(test_spec).flat_map do |dependent_target|
                spec_paths_to_include = dependent_target.non_test_specs.map(&:name)
                spec_paths_to_include << test_spec.name if dependent_target == target
                dependent_target.framework_paths.values_at(*spec_paths_to_include).flatten.compact.uniq
              end
              unless framework_paths.empty?
                input_paths = [script_path, *framework_paths.flat_map { |fw| [fw.source_path, fw.dsym_path] }.compact]
                output_paths = UserProjectIntegrator::TargetIntegrator.framework_output_paths(framework_paths)
              end
            end

            UserProjectIntegrator::TargetIntegrator.validate_input_output_path_limit(input_paths, output_paths)
            UserProjectIntegrator::TargetIntegrator.create_or_update_embed_frameworks_script_phase_to_target(native_target, script_path, input_paths, output_paths)
          end

          # @return [String] the message that should be displayed for the target
          #         integration.
          #
          def integration_message
            "Integrating target `#{target.name}`"
          end

          # @return [PodTarget] the target part of the installation result.
          #
          def target
            target_installation_result.target
          end

          # @param [Array<Specification] specs
          #         the specs to return script phrases from.
          #
          # @return [Array<Hash<Symbol=>String>] an array of all combined script phases from the specs.
          #
          def script_phases_for_specs(specs)
            specs.flat_map { |spec| spec.consumer(target.platform).script_phases }
          end
        end
      end
    end
  end
end
