module Pod
  class Installer
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
          target.test_native_targets.each do |native_target|
            add_embed_frameworks_script_phase(native_target)
            add_copy_resources_script_phase(native_target)
          end
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
        resource_paths = target.all_test_dependent_targets.flat_map(&:resource_paths)
        input_paths = []
        output_paths = []
        unless resource_paths.empty?
          input_paths = [script_path, *resource_paths.flatten.uniq]
          output_paths = ['${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}']
        end
        Pod::Installer::UserProjectIntegrator::TargetIntegrator.add_copy_resources_script_phase_to_target(native_target, script_path, input_paths, output_paths)
      end

      # Find or create a 'Embed Pods Frameworks' Copy Files Build Phase
      #
      # @return [void]
      #
      def add_embed_frameworks_script_phase(native_target)
        test_type = target.test_type_for_product_type(native_target.symbol_type)
        script_path = "${PODS_ROOT}/#{target.embed_frameworks_script_path_for_test_type(test_type).relative_path_from(target.sandbox.root)}"
        framework_paths = target.all_test_dependent_targets.flat_map(&:framework_paths)
        input_paths = []
        output_paths = []
        unless framework_paths.empty?
          input_paths = [script_path, *framework_paths.map { |fw| [fw[:input_path], fw[:dsym_input_path]] }.flatten.compact]
          output_paths = framework_paths.map { |fw| [fw[:output_path], fw[:dsym_output_path]] }.flatten.compact
        end
        Pod::Installer::UserProjectIntegrator::TargetIntegrator.add_embed_frameworks_script_phase_to_target(native_target, script_path, input_paths, output_paths)
      end

      # @return [String] the message that should be displayed for the target
      #         integration.
      #
      def integration_message
        "Integrating target `#{target.name}`"
      end
    end
  end
end
