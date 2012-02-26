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
    
    def self.integrate_with_project(projpath)
      # TODO use more of Pathname’s API here
      root = File.dirname(projpath)
      xcworkspace = File.join(root, File.basename(projpath, '.xcodeproj') + '.xcworkspace')
      workspace = Xcodeproj::Workspace.new_from_xcworkspace(xcworkspace)
      pods_projpath = File.join(config.project_pods_root, 'Pods.xcodeproj')
      root = Pathname.new(root).expand_path
      [projpath, pods_projpath].each do |path|
        path = Pathname.new(path).expand_path.relative_path_from(root).to_s
        workspace << path unless workspace.include? path
      end
      workspace.save_as(xcworkspace)

      app_project = Xcodeproj::Project.new(projpath)
      return if app_project.files.find { |file| file.path =~ /libPods\.a$/ }

      configfile = app_project.files.new('path' => 'Pods/Pods.xcconfig')
      app_project.targets.each do |target|
        target.buildConfigurations.each do |config|
          config.baseConfiguration = configfile
        end
      end
      
      libfile = app_project.files.new_static_library('Pods')
      libfile.group = app_project.main_group.groups.find { |g| g.name == 'Frameworks' }
      app_project.objects.select_by_class(Xcodeproj::Project::Object::PBXFrameworksBuildPhase).each do |build_phase|
        build_phase.files << libfile.buildFiles.new
      end
      
      copy_resources = app_project.add_shell_script_build_phase('Copy Pods Resources',
%{"${SRCROOT}/Pods/Pods-resources.sh"\n})
      app_project.targets.each { |target| target.buildPhases << copy_resources }
      
      app_project.save_as(projpath)

      unless config.silent?
        puts "[!] From now on use `#{File.basename(xcworkspace)}' instead of `#{File.basename(projpath)}'."
      end
    end
  end
end
