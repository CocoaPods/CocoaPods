module Pod
  class Installer
    autoload :TargetInstaller, 'cocoapods/installer/target_installer'

    module Shared
      def dependent_specifications
        @dependent_specifications ||= Resolver.new(@podfile, @definition ? @definition.dependencies : nil).resolve
      end

      def build_specifications
        dependent_specifications.reject do |spec|
          spec.wrapper? || spec.defined_in_set.only_part_of_other_pod?
        end
      end

      def download_only_specifications
        dependent_specifications - build_specifications
      end
    end

    include Config::Mixin
    include Shared

    def initialize(podfile)
      @podfile = podfile
    end

    def lock_file
      config.project_root + 'Podfile.lock'
    end

    def project
      return @project if @project
      @project = Xcodeproj::Project.for_platform(@podfile.platform)
      # First we need to resolve dependencies across *all* targets, so that the
      # same correct versions of pods are being used for all targets. This
      # happens when we call `build_specifications'.
      build_specifications.each do |spec|
        # Add all source files to the project grouped by pod
        group = @project.add_pod_group(spec.name)
        spec.expanded_source_files.each do |path|
          group.children.new('path' => path.to_s)
        end
      end
      # Add a group to hold all the target support files
      @project.main_group.groups.new('name' => 'Targets Support Files')
      @project
    end

    def target_installers
      @target_installers ||= @podfile.target_definitions.values.map do |definition|
        TargetInstaller.new(@podfile, project, definition) unless definition.empty?
      end.compact
    end

    def install_dependencies!
      build_specifications.each do |spec|
        if spec.pod_destroot.exist?
          puts "Using #{spec}" unless config.silent?
        else
          puts "Installing #{spec}" unless config.silent?
          spec = spec.part_of_specification if spec.part_of_other_pod?
          downloader = Downloader.for_source(spec.pod_destroot, spec.source)
          downloader.download
          # TODO move cleaning into the installer as well
          downloader.clean(spec.expanded_clean_paths) if config.clean
        end
      end
    end

    def install!
      puts "Installing dependencies of: #{@podfile.defined_in_file}" if config.verbose?
      install_dependencies!
      root = config.project_pods_root
      headers_symlink_root = config.headers_symlink_root

      # Clean old header symlinks
      FileUtils.rm_r(headers_symlink_root, :secure => true) if File.exists?(headers_symlink_root)

      puts "Generating support files" unless config.silent?
      target_installers.each do |target_installer|
        target_installer.install!
        target_installer.create_files_in(root)
      end
      generate_lock_file!

      puts "* Running post install hooks" if config.verbose?
      # Post install hooks run _before_ saving of project, so that they can alter it before saving.
      target_installers.each do |target_installer|
        target_installer.build_specifications.each { |spec| spec.post_install(target_installer) }
      end
      @podfile.post_install!(self)

      projpath = File.join(root, 'Pods.xcodeproj')
      puts "* Writing Xcode project file to `#{projpath}'" if config.verbose?
      project.save_as(projpath)
    end

    def generate_lock_file!
      lock_file.open('w') do |file|
        file.puts "PODS:"
        pods = build_specifications.map do |spec|
          [spec.to_s, spec.dependencies.map(&:to_s).sort]
        end.sort_by(&:first).each do |name, deps|
          if deps.empty?
            file.puts "  - #{name}"
          else
            file.puts "  - #{name}:"
            deps.each { |dep| file.puts "    - #{dep}" }
          end
        end

        unless download_only_specifications.empty?
          file.puts
          file.puts "DOWNLOAD_ONLY:"
          download_only_specifications.map(&:to_s).sort.each do |name|
            file.puts "  - #{name}"
          end
        end

        file.puts
        file.puts "DEPENDENCIES:"
        @podfile.dependencies.map(&:to_s).sort.each do |dep|
          file.puts "  - #{dep}"
        end
      end
    end

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
    def configure_project(projpath)
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
      app_project.objects.select_by_class(Xcodeproj::Project::PBXFrameworksBuildPhase).each do |build_phase|
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
