module Pod
  class Installer
    include Config::Mixin

    def initialize(specification)
      @specification = specification
    end

    def dependent_specification_sets
      @dependent_specification_sets ||= Resolver.new(@specification).resolve
    end

    def build_specification_sets
      dependent_specification_sets.reject(&:only_part_of_other_pod?)
    end

    def build_specifications
      build_specification_sets.map(&:specification)
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

    def template
      @template ||= ProjectTemplate.new(@specification.platform)
    end

    def xcodeproj
      unless @xcodeproj
        @xcodeproj = Xcode::Project.new(template.xcodeproj_path)
        target = @xcodeproj.targets.new_static_library('Pods')
        # TODO should create one programatically
        xcconfig_file = @xcodeproj.files.find { |file| file.path == 'Pods.xcconfig' }
        target.buildConfigurations.each do |config|
          config.baseConfiguration = xcconfig_file
        end
      end
      @xcodeproj
    end

    # TODO move xcconfig related code into the xcconfig method, like copy_resources_script and generate_bridge_support.
    def generate_project
      puts "==> Generating Xcode project and xcconfig" unless config.silent?
      user_header_search_paths = []
      target = xcodeproj.targets.first
      build_specifications.each do |spec|
        xcconfig.merge!(spec.xcconfig)
        group = xcodeproj.add_pod_group(spec.name)

        # Only add implementation files to the compile phase
        spec.implementation_files.each do |file|
          group << target.add_source_file(file, nil, spec.compiler_flags)
        end

        # Add header files to a `copy header build phase` for each destination
        # directory in the pod's header directory.
        spec.copy_header_mappings.each do |header_dir, files|
          copy_phase = target.copy_files_build_phases.new_pod_dir(spec.name, header_dir)
          files.each do |file|
            group << target.add_source_file(file, copy_phase)
          end
        end

        # Collect all header search paths
        user_header_search_paths.concat(spec.user_header_search_paths)
      end
      xcconfig.merge!('USER_HEADER_SEARCH_PATHS' => user_header_search_paths.sort.uniq.join(" "))
    end

    def copy_resources_script
      @copy_resources_script ||= Xcode::CopyResourcesScript.new(build_specifications.map do |spec|
        spec.expanded_resources
      end.flatten)
    end

    def bridge_support_generator
      BridgeSupportGenerator.new(build_specifications.map do |spec|
        spec.header_files.map do |header|
          config.project_pods_root + header
        end
      end.flatten)
    end

    def install!
      puts "Installing dependencies of: #{@specification.defined_in_file}" unless config.silent?
      build_specifications.each(&:install!)
      generate_project

      root = config.project_pods_root
      puts "  * Copying contents of template directory `#{template.path}' to `#{root}'" if config.verbose?
      template.copy_to(root)
      pbxproj = File.join(root, 'Pods.xcodeproj')
      puts "  * Writing Xcode project file to `#{pbxproj}'" if config.verbose?
      xcodeproj.save_as(pbxproj)
      xcconfig.create_in(root)
      if @specification.generate_bridge_support?
        path = bridge_support_generator.create_in(root)
        copy_resources_script.resources << path.relative_path_from(config.project_pods_root)
      end
      copy_resources_script.create_in(root)

      build_specifications.each(&:post_install)
    end
    
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
        'shellScript' => "${SRCROOT}/Pods/PodsResources.sh\n"
      })
      app_project.targets.each { |target| target.buildPhases << copy_resources }
      
      app_project.save_as(projpath)
    end
  end
end
