module Pod
  class Installer
    module Shared
      def dependent_specification_sets
        @dependent_specification_sets ||= Resolver.new(@podfile, @definition ? @definition.dependencies : nil).resolve
      end

      def build_specification_sets
        dependent_specification_sets.reject(&:only_part_of_other_pod?)
      end

      def build_specifications
        build_specification_sets.map(&:specification)
      end
    end

    class Target
      include Config::Mixin
      include Shared

      attr_reader :target

      def initialize(podfile, xcodeproj, definition)
        @podfile, @xcodeproj, @definition = podfile, xcodeproj, definition
      end

      def xcconfig
        @xcconfig ||= Xcode::Config.new({
          # In a workspace this is where the static library headers should be found.
          'USER_HEADER_SEARCH_PATHS' => '"$(BUILT_PRODUCTS_DIR)/Pods"',
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
        @copy_resources_script ||= Xcode::CopyResourcesScript.new(build_specifications.map do |spec|
          spec.expanded_resources
        end.flatten)
      end

      def copy_resources_filename
        "#{@definition.lib_name}-resources.sh"
      end

      def bridge_support_generator
        BridgeSupportGenerator.new(build_specifications.map do |spec|
          spec.header_files.map do |header|
            config.project_pods_root + header
          end
        end.flatten)
      end

      def bridge_support_filename
        "#{@definition.lib_name}.bridgesupport"
      end

      # TODO move out
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

      # TODO move xcconfig related code into the xcconfig method, like copy_resources_script and generate_bridge_support.
      def install!
        # First add the target to the project
        @target = @xcodeproj.targets.new_static_library(@definition.lib_name)

        user_header_search_paths = []
        build_specifications.each do |spec|
          xcconfig.merge!(spec.xcconfig)
          # Only add implementation files to the compile phase
          spec.implementation_files.each do |file|
            @target.add_source_file(file, nil, spec.compiler_flags)
          end
          # Add header files to a `copy header build phase` for each destination
          # directory in the pod's header directory.
          spec.copy_header_mappings.each do |header_dir, files|
            copy_phase = @target.copy_files_build_phases.new_pod_dir(spec.name, header_dir)
            files.each do |file|
              @target.add_source_file(file, copy_phase)
            end
          end
          # Collect all header search paths
          user_header_search_paths.concat(spec.user_header_search_paths)
        end
        xcconfig.merge!('USER_HEADER_SEARCH_PATHS' => user_header_search_paths.sort.uniq.join(" "))

        # Add all the target related support files to the group, even the copy
        # resources script although the project doesn't actually use them.
        support_files_group = @xcodeproj.groups.find do |group|
          group.name == "Targets Support Files"
        end.groups.new("name" => @definition.lib_name)
        support_files_group.files.new('path' => copy_resources_filename)
        prefix_file = support_files_group.files.new('path' => prefix_header_filename)
        xcconfig_file = support_files_group.files.new("path" => xcconfig_filename)
        # Assign the xcconfig as the base config of each config.
        @target.buildConfigurations.each do |config|
          config.baseConfiguration = xcconfig_file
          config.buildSettings['GCC_PREFIX_HEADER'] = prefix_header_filename
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

    def template
      @template ||= ProjectTemplate.new(@podfile.platform)
    end

    def xcodeproj
      unless @xcodeproj
        @xcodeproj = Xcode::Project.new(template.xcodeproj_path)
        # First we need to resolve dependencies across *all* targets, so that the
        # same correct versions of pods are being used for all targets. This
        # happens when we call `build_specifications'.
        build_specifications.each do |spec|
          # Add all source files to the project grouped by pod
          group = xcodeproj.add_pod_group(spec.name)
          spec.expanded_source_files.each do |path|
            group.children.new('path' => path.to_s)
          end
        end
        # Add a group to hold all the target support files
        xcodeproj.main_group.groups.new('name' => 'Targets Support Files')
      end
      @xcodeproj
    end

    def targets
      @targets ||= @podfile.targets.values.map do |target_definition|
        Target.new(@podfile, xcodeproj, target_definition)
      end
    end

    def install!
      puts "Installing dependencies of: #{@podfile.defined_in_file}" unless config.silent?
      build_specifications.each(&:install!)

      root = config.project_pods_root
      puts "  * Copying contents of template directory `#{template.path}' to `#{root}'" if config.verbose?
      template.copy_to(root)

      puts "==> Generating Xcode project and xcconfig" unless config.silent?
      targets.each do |target|
        target.install!
        target.create_files_in(root)
      end
      pbxproj = File.join(root, 'Pods.xcodeproj')
      puts "  * Writing Xcode project file to `#{pbxproj}'" if config.verbose?
      xcodeproj.save_as(pbxproj)

      # Post install hooks run last!
      targets.each do |target|
        target.build_specifications.each { |spec| spec.post_install(target) }
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
      root = File.dirname(projpath)
      xcworkspace = File.join(root, File.basename(projpath, '.xcodeproj') + '.xcworkspace')
      workspace = Xcode::Workspace.new_from_xcworkspace(xcworkspace)
      pods_projpath = File.join(config.project_pods_root, 'Pods.xcodeproj')
      root = Pathname.new(root).expand_path
      [projpath, pods_projpath].each do |path|
        path = Pathname.new(path).expand_path.relative_path_from(root).to_s
        workspace << path unless workspace.include? path
      end
      workspace.save_as(xcworkspace)

      app_project = Xcode::Project.new(projpath)
      return if app_project.files.find { |file| file.path =~ /libPods\.a$/ }

      configfile = app_project.files.new({
        'path' => 'Pods/Pods.xcconfig',
        'lastKnownFileType' => 'text.xcconfig'
      })
      app_project.targets.each do |target|
        target.buildConfigurations.each do |config|
          config.baseConfiguration = configfile
        end
      end
      app_project.main_group << configfile
      
      libfile = app_project.files.new({
        'path' => 'libPods.a',
        'lastKnownFileType' => 'archive.ar',
        'includeInIndex' => '0',
        'sourceTree' => 'BUILT_PRODUCTS_DIR'
      })
      app_project.objects.select_by_class(Xcode::Project::PBXFrameworksBuildPhase).each do |build_phase|
        build_phase.files << libfile.buildFiles.new
      end
      app_project.main_group << libfile
      
      copy_resources = app_project.objects.add(Xcode::Project::PBXShellScriptBuildPhase, {
        'name' => 'Copy Pods Resources',
        'buildActionMask' => '2147483647',
        'files' => [],
        'inputPaths' => [],
        'outputPaths' => [],
        'runOnlyForDeploymentPostprocessing' => '0',
        'shellPath' => '/bin/sh',
        'shellScript' => "${SRCROOT}/Pods/Pods-resources.sh\n"
      })
      app_project.targets.each { |target| target.buildPhases << copy_resources }
      
      app_project.save_as(projpath)
    end
  end
end
