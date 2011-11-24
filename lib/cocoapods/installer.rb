module Pod
  class Installer
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

    class TargetInstaller
      include Config::Mixin
      include Shared

      attr_reader :podfile, :project, :definition, :target

      def initialize(podfile, project, definition)
        @podfile, @project, @definition = podfile, project, definition
      end

      def xcconfig
        @xcconfig ||= Xcodeproj::Config.new({
          # In a workspace this is where the static library headers should be found.
          'PODS_ROOT' => '$(SRCROOT)/Pods',
          'HEADER_SEARCH_PATHS' => '"$(PODS_ROOT)/Headers"',
          'ALWAYS_SEARCH_USER_PATHS' => 'YES',
          # This makes categories from static libraries work, which many libraries
          # require, so we add these by default.
          'OTHER_LDFLAGS'            => '-ObjC -all_load',
        })
      end

      def xcconfig_filename
        "#{@definition.lib_name}.xcconfig"
      end

      def copy_resources_script
        @copy_resources_script ||= Generator::CopyResourcesScript.new(build_specifications.map do |spec|
          spec.expanded_resources
        end.flatten)
      end

      def copy_resources_filename
        "#{@definition.lib_name}-resources.sh"
      end

      def bridge_support_generator
        Generator::BridgeSupport.new(build_specifications.map do |spec|
          spec.header_files.map do |header|
            config.project_pods_root + header
          end
        end.flatten)
      end

      def bridge_support_filename
        "#{@definition.lib_name}.bridgesupport"
      end

      # TODO move out to Generator::PrefixHeader
      def save_prefix_header_as(pathname)
        pathname.open('w') do |header|
          header.puts "#ifdef __OBJC__"
          header.puts "#import #{@podfile.platform == :ios ? '<UIKit/UIKit.h>' : '<Cocoa/Cocoa.h>'}"
          header.puts "#endif"
        end
      end

      def prefix_header_filename
        "#{@definition.lib_name}-prefix.pch"
      end

      def headers_symlink_path_name
        "#{config.project_pods_root}/Headers"
      end

      # TODO move xcconfig related code into the xcconfig method, like copy_resources_script and generate_bridge_support.
      def install!
        # First add the target to the project
        @target = @project.targets.new_static_library(@definition.lib_name)

        # Clean old header symlinks
        FileUtils.rm_r(headers_symlink_path_name, :secure => true) if File.exists?(headers_symlink_path_name)

        header_search_paths = []
        build_specifications.each do |spec|
          xcconfig.merge!(spec.xcconfig)
          # Only add implementation files to the compile phase
          spec.implementation_files.each do |file|
            @target.add_source_file(file, nil, spec.compiler_flags)
          end
          # Symlink header files to Pods/Headers
          spec.copy_header_mappings.each do |header_dir, files|
            target_dir = "#{headers_symlink_path_name}/#{header_dir}"
            FileUtils.mkdir_p(target_dir)
            target_dir_real_path = Pathname.new(target_dir).realpath
            files.each do |file|
              source = Pathname.new("#{config.project_pods_root}/#{file}").realpath.relative_path_from(target_dir_real_path)
              Dir.chdir(target_dir) do
                FileUtils.ln_sf(source, File.basename(file))
              end
            end
          end
          # Collect all header search paths
          header_search_paths.concat(spec.header_search_paths)
        end
        xcconfig.merge!('HEADER_SEARCH_PATHS' => header_search_paths.sort.uniq.join(" "))

        # Now that we have added all the source files and copy header phases,
        # move the compile build phase to the end, so that headers are copied
        # to the build products dir first, and thus Pod source files can enjoy
        # the same namespacing of headers as the app would.
        @target.move_compile_phase_to_end!

        # Add all the target related support files to the group, even the copy
        # resources script although the project doesn't actually use them.
        support_files_group = @project.groups.find do |group|
          group.name == "Targets Support Files"
        end.groups.new("name" => @definition.lib_name)
        support_files_group.files.new('path' => copy_resources_filename)
        prefix_file = support_files_group.files.new('path' => prefix_header_filename)
        xcconfig_file = support_files_group.files.new("path" => xcconfig_filename)
        # Assign the xcconfig as the base config of each config.
        @target.buildConfigurations.each do |config|
          config.baseConfiguration = xcconfig_file
          config.buildSettings['OTHER_LDFLAGS'] = ''
          config.buildSettings['GCC_PREFIX_HEADER'] = prefix_header_filename
          config.buildSettings['PODS_ROOT'] = '$(SRCROOT)'
        end
      end

      def create_files_in(root)
        xcconfig.save_as(root + xcconfig_filename)
        if @podfile.generate_bridge_support?
          bridge_support_generator.save_as(root + bridge_support_filename)
          copy_resources_script.resources << bridge_support_filename
        end
        save_prefix_header_as(root + prefix_header_filename)
        copy_resources_script.save_as(root + copy_resources_filename)
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

    def install!
      puts "Installing dependencies of: #{@podfile.defined_in_file}" unless config.silent?
      build_specifications.each(&:install!)
      root = config.project_pods_root

      puts "==> Generating support files" unless config.silent?
      target_installers.each do |target_installer|
        target_installer.install!
        target_installer.create_files_in(root)
      end
      generate_lock_file!

      puts "==> Running post install hooks" unless config.silent?
      # Post install hooks run _before_ saving of project, so that they can alter it before saving.
      target_installers.each do |target_installer|
        target_installer.build_specifications.each { |spec| spec.post_install(target_installer) }
      end
      @podfile.post_install!(self)

      puts "==> Generating Xcode project" unless config.silent?
      projpath = File.join(root, 'Pods.xcodeproj')
      puts "  * Writing Xcode project file to `#{projpath}'" if config.verbose?
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
