require 'xcodeproj/workspace'
require 'xcodeproj/project'

module Pod
  class ProjectIntegration
    extend Pod::Config::Mixin
    
    # For now this assumes just one pods target, i.e. only libPods.a.
    # Not sure yet if we should try to be smart with apps that have multiple
    # targets and try to map pod targets to those app targets.
    #
    # Possible options are:
    # 1. Only cater to the most simple setup
    # 2. Try to automagically figure it out by name. For example, a pod target
    #    called `:some_target' could map to an app target called `SomeTarget'.
    #    (A variation would be to not even camelize the target name, but simply
    #    let the user specify it with the proper case.)
    # 3. Let the user specify the app target name as an extra argument, but this
    #    seems to be a less good version of the variation on #2.

    class << self
      def integrate_with_project(projpath)
        root = File.dirname(projpath)
        name = File.basename(projpath, '.xcodeproj')
        
        xcworkspace = create_workspace(root, name, projpath)
        app_project = Xcodeproj::Project.new(projpath)

        return if project_already_integrated?(app_project)

        xcconfig = app_project.files.new('path' => 'Pods/Pods.xcconfig')
        base_project_configurations_on_xcconfig(app_project, xcconfig)
      
        libfile = app_project.files.new_static_library('Pods')
        libfile.group = app_project.group("Frameworks")
        
        add_pods_library_to_each_target_in_project(app_project, libfile)
      
        copy_resources = app_project.add_shell_script_build_phase(
          'Copy Pods Resources', %{"${SRCROOT}/Pods/Pods-resources.sh"\n})
          
        add_copy_resources_script_phase_to_each_target_in_project(app_project, copy_resources)
      
        app_project.save_as(projpath)

        unless config.silent?
          # TODO this really shouldn't be here
          puts "[!] From now on use `#{File.basename(xcworkspace)}' instead of `#{File.basename(projpath)}'."
        end
      end
      
      def create_workspace(in_directory, name, project_path)
        workspace_path = File.join(in_directory, name + '.xcworkspace')
        workspace = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)
        pods_project_path = File.join(config.project_pods_root, 'Pods.xcodeproj')
        root = Pathname.new(in_directory).expand_path
        [project_path, pods_project_path].each do |path|
          path = Pathname.new(path).expand_path.relative_path_from(root).to_s
          workspace << path unless workspace.include?(path)
        end
        workspace.save_as(workspace_path)
      end
      
      def project_already_integrated?(project)
        project.files.find { |file| file.path =~ /libPods\.a$/ }
      end
      
      def base_project_configurations_on_xcconfig(project, xcconfig_file)
        project.targets.each do |target|
          target.buildConfigurations.each do |config|
            config.baseConfiguration = xcconfig_file
          end
        end
      end
      
      def add_pods_library_to_each_target_in_project(project, pods_library)
        project.targets.each do |target|
          target.frameworks_build_phases.each do |build_phase|
            build_phase.files << pods_library.buildFiles.new
          end
        end
      end
      
      def add_copy_resources_script_phase_to_each_target_in_project(project, copy_resources_script_phase)
        project.targets.each { |target| target.buildPhases << copy_resources_script_phase }
      end
    end
  end
end
