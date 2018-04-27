module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        # This class is responsible for integrating a pod target. This includes integrating
        # the test targets included by each pod target.
        #
        class PodTargetIntegrator
          # @return [PodTarget] the target that should be integrated.
          #
          attr_reader :target

          # Init a new PodTargetIntegrator.
          #
          # @param  [PodTarget] target @see #target
          #
          def initialize(target)
            @target = target
          end

          # Integrates the pod target.
          #
          # @return [void]
          #
          def integrate!
            UI.section(integration_message) do
              target.test_specs_by_native_target.each do |native_target, test_specs|
                add_embed_frameworks_script_phase(native_target)
                add_copy_resources_script_phase(native_target)
                UserProjectIntegrator::TargetIntegrator.create_or_update_user_script_phases(script_phases_for_specs(test_specs), native_target)
              end
              specs = target.non_test_specs
              UserProjectIntegrator::TargetIntegrator.create_or_update_user_script_phases(script_phases_for_specs(specs), target.native_target)
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
          def add_copy_resources_script_phase(native_target)
            test_type = target.test_type_for_product_type(native_target.symbol_type)
            script_path = "${PODS_ROOT}/#{target.copy_resources_script_path_for_test_type(test_type).relative_path_from(target.sandbox.root)}"
            resource_paths = target.all_dependent_targets.flat_map do |dependent_target|
              include_test_spec_paths = dependent_target == target
              dependent_target.resource_paths(include_test_spec_paths)
            end
            input_paths = []
            output_paths = []
            unless resource_paths.empty?
              resource_paths_flattened = resource_paths.flatten.uniq
              input_paths = [script_path, *resource_paths_flattened]
              output_paths = UserProjectIntegrator::TargetIntegrator.resource_output_paths(resource_paths_flattened)
            end
            UserProjectIntegrator::TargetIntegrator.validate_input_output_path_limit(input_paths, output_paths)
            UserProjectIntegrator::TargetIntegrator.create_or_update_copy_resources_script_phase_to_target(native_target, script_path, input_paths, output_paths)
          end

          # Find or create a 'Embed Pods Frameworks' Copy Files Build Phase
          #
          # @return [void]
          #
          def add_embed_frameworks_script_phase(native_target)
            test_type = target.test_type_for_product_type(native_target.symbol_type)
            script_path = "${PODS_ROOT}/#{target.embed_frameworks_script_path_for_test_type(test_type).relative_path_from(target.sandbox.root)}"
            all_dependent_targets = target.all_dependent_targets
            framework_paths = all_dependent_targets.flat_map do |dependent_target|
              include_test_spec_paths = dependent_target == target
              dependent_target.framework_paths(include_test_spec_paths)
            end
            input_paths = []
            output_paths = []
            unless framework_paths.empty?
              input_paths = [script_path, *framework_paths.flat_map { |fw| [fw[:input_path], fw[:dsym_input_path]] }.compact]
              output_paths = framework_paths.flat_map { |fw| [fw[:output_path], fw[:dsym_output_path]] }.compact
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
