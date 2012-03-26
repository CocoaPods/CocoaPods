require 'xcodeproj/workspace'
require 'xcodeproj/project'

module Pod
  class Project

    class Integrator
      include Pod::Config::Mixin

      attr_reader :user_project_path, :user_project

      def initialize(user_project_path)
        @user_project_path = user_project_path
        @user_project = Xcodeproj::Project.new(user_project_path)
      end

      def integrate!
        create_workspace!
        return if project_already_integrated?

        base_user_project_configurations_on_xcconfig
        add_pods_library_to_each_target
        add_copy_resources_script_phase_to_each_target
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

      def base_user_project_configurations_on_xcconfig
        xcconfig = @user_project.files.new('path' => 'Pods/Pods.xcconfig')
        user_project.targets.each do |target|
          target.build_configurations.each do |config|
            config.base_configuration = xcconfig
          end
        end
      end

      def add_pods_library_to_each_target
        pods_library = @user_project.group("Frameworks").files.new_static_library('Pods')
        @user_project.targets.each do |target|
          target.frameworks_build_phases.each do |build_phase|
            build_phase.files << pods_library.build_files.new
          end
        end
      end

      def add_copy_resources_script_phase_to_each_target
        @user_project.targets.each do |target|
          phase = target.shell_script_build_phases.new
          phase.name = 'Copy Pods Resources'
          phase.shell_script = %{"${SRCROOT}/Pods/Pods-resources.sh"\n}
        end
      end
    end

  end
end
