require 'xcodeproj/workspace'
require 'xcodeproj/project'

module Pod
  class Installer

    class UserProjectIntegrator
      include Pod::Config::Mixin

      def initialize(podfile)
        @podfile = podfile
      end

      def integrate!
        create_workspace!

        # Only need to write out the user's project if any of the target
        # integrators actually did some work.
        target_integrators.map(&:integrate!)
      end

      def workspace_path
        @podfile.workspace || raise(Informative, "Could not automatically select an Xcode workspace. " \
                                                 "Specify one in your Podfile.")
      end

      def pods_project_path
        config.project_root + "Pods/Pods.xcodeproj"
      end

      def target_integrators
        @target_integrators ||= @podfile.target_definitions.values.map do |definition|
          TargetIntegrator.new(definition) unless definition.empty?
        end.compact
      end

      def user_project_paths
        @podfile.target_definitions.values.map do |td|
          next if td.empty?
          td.user_project.path #|| raise(Informative, "Could not resolve the Xcode project in which the " \
                               #                      "`#{td.name}' target should be integrated.")
        end.compact
      end

      def create_workspace!
        workspace = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)
        [pods_project_path, *user_project_paths].each do |project_path|
          project_path = project_path.relative_path_from(config.project_root).to_s
          workspace << project_path unless workspace.include?(project_path)
        end
        unless workspace_path.exist? || config.silent?
          puts "[!] From now on use `#{workspace_path.basename}'."
        end
        workspace.save_as(workspace_path)
      end

      class TargetIntegrator
        attr_reader :target_definition

        def initialize(target_definition)
          @target_definition = target_definition
        end

        def inspect
          "#<#{self.class} for target `#{@target_definition.label}'>"
        end

        def integrate!
          return if targets.empty?

          unless Config.instance.silent?
            # TODO let's just use ActiveSupport.
            plural = targets.size > 1
            puts "-> Integrating `#{@target_definition.lib_name}' into target#{'s' if plural} " \
                 "`#{targets.map(&:name).join(', ')}' of Xcode project `#{user_project_path.basename}'.".green
          end

          add_xcconfig_base_configuration
          add_pods_library
          add_copy_resources_script_phase
          user_project.save_as(@target_definition.user_project.path)
        end

        def user_project_path
          if path = @target_definition.user_project.path
            unless path.exist?
              raise Informative, "The Xcode project `#{path}' does not exist."
            end
            path
          else
            raise Informative, "Could not automatically select an Xcode project.\n" \
                               "Specify one in your Podfile like so:\n\n" \
                               "  xcodeproj 'path/to/XcodeProject'"
          end
        end

        def user_project
          @user_project ||= Xcodeproj::Project.new(user_project_path)
        end

        # This returns a list of the targets from the user’s project to which
        # this Pods static library should be linked. If no explicit target was
        # specified, then the first encountered target is assumed.
        #
        # In addition this will only return targets that do **not** already
        # have the Pods library in their frameworks build phase.
        #
        # @return [Array<PBXNativeTarget>]  Returns the list of targets that
        #                                   the Pods lib should be linked with.
        def targets
          @targets ||= begin
          if link_with = @target_definition.link_with
            # Find explicitly linked targets.
            user_project.targets.select do |target|
              link_with.include? target.name
            end
          elsif @target_definition.name != :default
            # Find the target with the matching name.
            target = user_project.targets.find { |target| target.name == @target_definition.name.to_s }
            raise Informative, "Unable to find a target named `#{@target_definition.name.to_s}'" unless target
            [target]
          else
            # Default to the first, which in a simple project is probably an app target.
            [user_project.targets.first]
          end.reject do |target|
              # Reject any target that already has this Pods library in one of its frameworks build phases
              target.frameworks_build_phases.any? do |phase|
                phase.files.any? { |file| file.name == @target_definition.lib_name }
              end
            end
          end
        end

        def add_xcconfig_base_configuration
          xcconfig = user_project.files.new('path' => @target_definition.xcconfig_relative_path)
          targets.each do |target|
            target.build_configurations.each do |config|
              config.base_configuration = xcconfig
            end
          end
        end

        def add_pods_library
          framework_group = user_project.group("Frameworks")
          raise Informative, "Cannot add pod library to project. Please check if the project have a 'Frameworks' group in the root of the project." unless framework_group

          pods_library = framework_group.files.new_static_library(@target_definition.label)
          targets.each do |target|
            target.frameworks_build_phases.each { |build_phase| build_phase << pods_library }
          end
        end

        def add_copy_resources_script_phase
          targets.each do |target|
            phase = target.shell_script_build_phases.new
            phase.name = 'Copy Pods Resources'
            phase.shell_script = %{"#{@target_definition.copy_resources_script_relative_path}"\n}
          end
        end
      end

    end

  end
end
