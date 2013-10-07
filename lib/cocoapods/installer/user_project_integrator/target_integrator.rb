require 'active_support'

module Pod
  class Installer
    class UserProjectIntegrator

      # This class is responsible for integrating the library generated by a
      # {TargetDefinition} with its destination project.
      #
      class TargetIntegrator

        # @return [Target] the target that should be integrated.
        #
        attr_reader :target

        # @param  [Target] target @see #target_definition
        #
        def initialize(target)
          @target = target
        end

        # Integrates the user project targets. Only the targets that do **not**
        # already have the Pods library in their frameworks build phase are
        # processed.
        #
        # @return [void]
        #
        def integrate!
          validate
          return if native_targets.empty?
          UI.section(integration_message) do
            set_xcconfig
            add_pods_library
            add_copy_resources_script_phase
            add_check_manifest_lock_script_phase
            user_project.save
          end
        end

        # @return [String] a string representation suitable for debugging.
        #
        def inspect
          "#<#{self.class} for target `#{target.name}'>"
        end


        private

        # @!group Integration steps
        #---------------------------------------------------------------------#

        # Validates the inputs provided to the integrator.
        #
        # @returns [void]
        #
        def validate
          raise "Empty user UUIDs for target `#{target}`" if target.user_target_uuids.empty?
          raise "Missing project path for target `#{target}`" unless target.user_project_path
          raise "Missing xcconfig path for target `#{target}`" unless target.xcconfig_path
          raise "Missing copy resources script path for target `#{target}`" unless target.copy_resources_script_path
        end

        # @return [Specification::Consumer] the consumer for the specifications.
        #
        def spec_consumers
          @spec_consumers ||= target.children.map(&:file_accessors).flatten.map(&:spec_consumer)
        end

        # Adds the `xcconfig` configurations files generated for the current
        # {TargetDefinition} to the build configurations of the targets that
        # should be integrated.
        #
        # @note   It also checks if any build setting of the build
        #         configurations overrides the `xcconfig` file and warns the
        #         user.
        #
        # @todo   If the xcconfig is already set don't override it and inform
        #         the user.
        #
        # @return [void]
        #
        def set_xcconfig
          xcconfig = user_project.files.select { |f| f.path == xcconfig_relative_path }.first ||
            user_project.new_file(xcconfig_relative_path)
          native_targets.each do |native_target|
            check_overridden_build_settings(target.xcconfig, native_target)
            native_target.build_configurations.each do |config|
              config.base_configuration_reference = xcconfig
            end
          end
        end

        # Adds spec libraries to the frameworks build phase of the
        # {TargetDefinition} integration libraries. Adds a file reference to
        # the library of the {TargetDefinition} and adds it to the frameworks
        # build phase of the targets.
        #
        # @return [void]
        #
        def add_pods_library
          frameworks = user_project.frameworks_group
          native_targets.each do |native_target|
            library = frameworks.files.select { |f| f.path == target.product_name }.first ||
              frameworks.new_product_ref_for_target(target.name, :static_library)
            unless native_target.frameworks_build_phase.files_references.include?(library)
              native_target.frameworks_build_phase.add_file_reference(library)
            end
          end
        end

        # Adds a shell script build phase responsible to copy the resources
        # generated by the TargetDefinition to the bundle of the product of the
        # targets.
        #
        # @return [void]
        #
        def add_copy_resources_script_phase
          phase_name = "Copy Pods Resources"
          native_targets.each do |native_target|
            phase = native_target.shell_script_build_phases.select { |bp| bp.name == phase_name }.first ||
              native_target.new_shell_script_build_phase(phase_name)
            path = "${SRCROOT}/#{copy_resources_script_path}"
            phase.shell_script = %{"#{path}"\n}
            phase.show_env_vars_in_log = '0'
          end
        end

        # Adds a shell script build phase responsible for checking if the Pods
        # locked in the Pods/Manifest.lock file are in sync with the Pods defined
        # in the Podfile.lock.
        #
        # @note   The build phase is appended to the front because to fail
        #         fast.
        #
        # @return [void]
        #
        def add_check_manifest_lock_script_phase
          phase_name = 'Check Pods Manifest.lock'
          native_targets.each do |native_target|
            next if native_target.shell_script_build_phases.any? { |phase| phase.name == phase_name }
            phase = native_target.project.new(Xcodeproj::Project::Object::PBXShellScriptBuildPhase)
            native_target.build_phases.unshift(phase)
            phase.name = phase_name
            phase.shell_script = <<-EOS.strip_heredoc
              diff "${PODS_ROOT}/../Podfile.lock" "${PODS_ROOT}/Manifest.lock" > /dev/null
              if [[ $? != 0 ]] ; then
                  cat << EOM
              error: The sandbox is not in sync with the Podfile.lock. Run 'pod install' or update your CocoaPods installation.
              EOM
                  exit 1
              fi
            EOS
            phase.show_env_vars_in_log = '0'
          end
        end


        private

        # @!group Private helpers.
        #---------------------------------------------------------------------#

        # @return [Array<PBXNativeTarget>] the user targets for integration.
        #
        def native_targets
          unless @native_targets
            target_uuids = target.user_target_uuids
            native_targets = target_uuids.map do |uuid|
              native_target = user_project.objects_by_uuid[uuid]
              unless native_target
                raise Informative, "[Bug] Unable to find the target with " \
                  "the `#{uuid}` UUID for the `#{target}` integration library"
              end
              native_target
            end
            non_integrated = native_targets.reject do |native_target|
              native_target.frameworks_build_phase.files.any? do |build_file|
                file_ref = build_file.file_ref
                file_ref &&
                  file_ref.isa == 'PBXFileReference' &&
                  file_ref.display_name == target.product_name
              end
            end
            @native_targets = non_integrated
          end
          @native_targets
        end

        # Read the project from the disk to ensure that it is up to date as
        # other TargetIntegrators might have modified it.
        #
        def user_project
          @user_project ||= Xcodeproj::Project.open(target.user_project_path)
        end

        # @return [Pathname]
        #
        def xcconfig_relative_path
          target.xcconfig_path.relative_path_from(user_project.path.dirname)
        end

        # @return [Pathname]
        #
        def copy_resources_script_path
          target.copy_resources_script_path.relative_path_from(user_project.path.dirname)
        end

        # Informs the user about any build setting of the target which might
        # override the given xcconfig file.
        #
        # @return [void]
        #
        def check_overridden_build_settings(xcconfig, native_target)
          return unless xcconfig

          configs_by_overridden_key = {}
          native_target.build_configurations.each do |config|
            xcconfig.attributes.keys.each do |key|
              target_value = config.build_settings[key]

              if target_value && !target_value.include?('$(inherited)')
                configs_by_overridden_key[key] ||= []
                configs_by_overridden_key[key] << config.name
              end
            end

            configs_by_overridden_key.each do |key, config_names|
              name    = "#{native_target.name} [#{config_names.join(' - ')}]"
              actions = [
                "Use the `$(inherited)` flag, or",
                "Remove the build settings from the target."
              ]
              UI.warn("The target `#{name}` overrides the `#{key}` build " \
                      "setting defined in `#{xcconfig_relative_path}'.",
                      actions)
            end
          end
        end

        # @return [String] the message that should be displayed for the target
        #         integration.
        #
        def integration_message
          "Integrating Pod #{'target'.pluralize(target.children.size)} " \
            "`#{target.children.map(&:name).to_sentence}` " \
            "into aggregate target #{target.name} " \
            "of project #{UI.path target.user_project_path}."
        end

        #---------------------------------------------------------------------#

      end
    end
  end
end
