require 'xcodeproj/workspace'
require 'xcodeproj/project'

module Pod
  class Project

    class Integrator
      include Pod::Config::Mixin

      attr_reader :user_project_path, :user_project

      def initialize(user_project_path, podfile)
        @user_project_path = user_project_path
        @podfile = podfile
        @user_project = Xcodeproj::Project.new(user_project_path)
      end

      def integrate!
        create_workspace!
        return if project_already_integrated?

        targets.each(&:integrate!)
        @user_project.save_as(user_project_path)

        unless config.silent?
          # TODO this really shouldn't be here
          puts "[!] From now on use `#{xcworkspace_path.basename}' instead of `#{user_project_path.basename}'."
        end
      end

      def workspace_path
        config.project_root + "#{user_project_path.basename('.xcodeproj')}.xcworkspace"
      end

      def pods_project_path
        config.project_root + "Pods/Pods.xcodeproj"
      end

      def targets
        @podfile.target_definitions.values.map { |definition| Target.new(self, definition) }
      end

      def create_workspace!
        workspace = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)
        [user_project_path, pods_project_path].each do |project_path|
          project_path = project_path.relative_path_from(config.project_root).to_s
          workspace << project_path unless workspace.include?(project_path)
        end
        workspace.save_as(workspace_path)
      end

      def project_already_integrated?
        @user_project.files.find { |file| file.path =~ /libPods\.a$/ }
      end

      class Target
        attr_reader :integrator, :target_definition

        def initialize(integrator, target_definition)
          @integrator, @target_definition = integrator, target_definition
        end

        def integrate!
          add_xcconfig_base_configuration
          add_pods_library
          add_copy_resources_script_phase
        end

        # @return [Array<PBXNativeTarget>]  Returns the list of targets that
        #                                   the Pods lib should be linked with.
        def targets
          @integrator.user_project.targets.select do |target|
            @target_definition.link_with.include? target.name
          end
        end

        def add_xcconfig_base_configuration
          xcconfig = @integrator.user_project.files.new('path' => "Pods/#{@target_definition.xcconfig_name}") # TODO use Sandbox?
          targets.each do |target|
            target.build_configurations.each do |config|
              config.base_configuration = xcconfig
            end
          end
        end

        def add_pods_library
          pods_library = @integrator.user_project.group("Frameworks").files.new_static_library(@target_definition.label)
          targets.each do |target|
            target.frameworks_build_phases.each do |build_phase|
              build_phase.files << pods_library.build_files.new
            end
          end
        end

        def add_copy_resources_script_phase
          targets.each do |target|
            phase = target.shell_script_build_phases.new
            phase.name = 'Copy Pods Resources'
            phase.shell_script = %{"${SRCROOT}/Pods/#{@target_definition.copy_resources_script_name}"\n}
          end
        end
      end

    end

  end
end
