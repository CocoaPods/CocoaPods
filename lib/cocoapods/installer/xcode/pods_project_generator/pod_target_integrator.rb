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

          # @return [Boolean] whether to use input/output paths for build phase scripts
          #
          attr_reader :use_input_output_paths
          alias use_input_output_paths? use_input_output_paths

          # Initialize a new instance
          #
          # @param  [TargetInstallationResult] target_installation_result @see #target_installation_result
          # @param  [Boolean] use_input_output_paths @see #use_input_output_paths
          #
          def initialize(target_installation_result, use_input_output_paths: true)
            @target_installation_result = target_installation_result
            @use_input_output_paths = use_input_output_paths
          end

          # Integrates the pod target.
          #
          # @return [void]
          #
          def integrate!
            UI.section(integration_message) do
              target_installation_result.non_library_specs_by_native_target.each do |native_target, spec|
                add_embed_frameworks_script_phase(native_target, spec)
                add_copy_resources_script_phase(native_target, spec)
                UserProjectIntegrator::TargetIntegrator.create_or_update_user_script_phases(script_phases_for_specs(spec), native_target)
              end
              UserProjectIntegrator::TargetIntegrator.create_or_update_user_script_phases(script_phases_for_specs(target.library_specs), target_installation_result.native_target)
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
          def add_copy_resources_script_phase(native_target, spec)
            script_path = "${PODS_ROOT}/#{target.copy_resources_script_path_for_spec(spec).relative_path_from(target.sandbox.root)}"

            input_paths_by_config = {}
            output_paths_by_config = {}

            dependent_targets = if spec.test_specification?
                                  target.dependent_targets_for_test_spec(spec)
                                else
                                  target.dependent_targets_for_app_spec(spec)
                                end
            host_target_spec_names = target.app_host_dependent_targets_for_spec(spec).flat_map do |pt|
              pt.specs.map(&:name)
            end.uniq
            resource_paths = dependent_targets.flat_map do |dependent_target|
              spec_paths_to_include = dependent_target.library_specs.map(&:name)
              spec_paths_to_include -= host_target_spec_names
              spec_paths_to_include << spec.name if dependent_target == target
              dependent_target.resource_paths.values_at(*spec_paths_to_include).flatten.compact
            end.uniq

            if use_input_output_paths? && !resource_paths.empty?
              input_file_list_path = target.copy_resources_script_input_files_path_for_spec(spec)
              input_file_list_relative_path = "${PODS_ROOT}/#{input_file_list_path.relative_path_from(target.sandbox.root)}"
              input_paths_key = UserProjectIntegrator::TargetIntegrator::XCFileListConfigKey.new(input_file_list_path, input_file_list_relative_path)
              input_paths_by_config[input_paths_key] = [script_path] + resource_paths

              output_file_list_path = target.copy_resources_script_output_files_path_for_spec(spec)
              output_file_list_relative_path = "${PODS_ROOT}/#{output_file_list_path.relative_path_from(target.sandbox.root)}"
              output_paths_key = UserProjectIntegrator::TargetIntegrator::XCFileListConfigKey.new(output_file_list_path, output_file_list_relative_path)
              output_paths_by_config[output_paths_key] = UserProjectIntegrator::TargetIntegrator.resource_output_paths(resource_paths)
            end

            if resource_paths.empty?
              UserProjectIntegrator::TargetIntegrator.remove_copy_resources_script_phase_from_target(native_target)
            else
              UserProjectIntegrator::TargetIntegrator.create_or_update_copy_resources_script_phase_to_target(
                native_target, script_path, input_paths_by_config, output_paths_by_config)
            end
          end

          # Find or create a 'Embed Pods Frameworks' Copy Files Build Phase
          #
          # @return [void]
          #
          def add_embed_frameworks_script_phase(native_target, spec)
            script_path = "${PODS_ROOT}/#{target.embed_frameworks_script_path_for_spec(spec).relative_path_from(target.sandbox.root)}"

            input_paths_by_config = {}
            output_paths_by_config = {}

            dependent_targets = if spec.test_specification?
                                  target.dependent_targets_for_test_spec(spec)
                                else
                                  target.dependent_targets_for_app_spec(spec)
                                end
            host_target_spec_names = target.app_host_dependent_targets_for_spec(spec).flat_map do |pt|
              pt.specs.map(&:name)
            end.uniq
            framework_paths = dependent_targets.flat_map do |dependent_target|
              spec_paths_to_include = dependent_target.library_specs.map(&:name)
              spec_paths_to_include -= host_target_spec_names
              spec_paths_to_include << spec.name if dependent_target == target
              dependent_target.framework_paths.values_at(*spec_paths_to_include).flatten.compact
            end.uniq

            if use_input_output_paths? && !framework_paths.empty?
              input_file_list_path = target.embed_frameworks_script_input_files_path_for_spec(spec)
              input_file_list_relative_path = "${PODS_ROOT}/#{input_file_list_path.relative_path_from(target.sandbox.root)}"
              input_paths_key = UserProjectIntegrator::TargetIntegrator::XCFileListConfigKey.new(input_file_list_path, input_file_list_relative_path)
              input_paths = input_paths_by_config[input_paths_key] = [script_path]
              framework_paths.each do |path|
                input_paths.concat(path.all_paths)
              end

              output_file_list_path = target.embed_frameworks_script_output_files_path_for_spec(spec)
              output_file_list_relative_path = "${PODS_ROOT}/#{output_file_list_path.relative_path_from(target.sandbox.root)}"
              output_paths_key = UserProjectIntegrator::TargetIntegrator::XCFileListConfigKey.new(output_file_list_path, output_file_list_relative_path)
              output_paths_by_config[output_paths_key] = UserProjectIntegrator::TargetIntegrator.framework_output_paths(framework_paths)
            end

            if framework_paths.empty?
              UserProjectIntegrator::TargetIntegrator.remove_embed_frameworks_script_phase_from_target(native_target)
            else
              UserProjectIntegrator::TargetIntegrator.create_or_update_embed_frameworks_script_phase_to_target(
                native_target, script_path, input_paths_by_config, output_paths_by_config)
            end
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

          # @param [Specification, Array<Specification>] specs
          #         the specs to return script phrases from.
          #
          # @return [Array<Hash<Symbol=>String>] an array of all combined script phases from the specs.
          #
          def script_phases_for_specs(specs)
            Array(specs).flat_map { |spec| spec.consumer(target.platform).script_phases }
          end
        end
      end
    end
  end
end
