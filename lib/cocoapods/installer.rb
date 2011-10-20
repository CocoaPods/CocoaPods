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

    def xcodeproj
      @xcodeproj ||= Xcode::Project.static_library(@specification.platform)
    end

    # TODO move xcconfig related code into the xcconfig method, like copy_resources_script and generate_bridge_support.
    def generate_project
      puts "==> Generating Xcode project and xcconfig" unless config.silent?
      user_header_search_paths = []
      build_specifications.each do |spec|
        xcconfig.merge!(spec.xcconfig)
        group = xcodeproj.add_pod_group(spec.name)

        # Only add implementation files to the compile phase
        spec.implementation_files.each do |file|
          group.add_source_file(file, nil, spec.compiler_flags)
        end

        # Add header files to a `copy header build phase` for each destination
        # directory in the pod's header directory.
        spec.copy_header_mappings.each do |header_dir, files|
          copy_phase = xcodeproj.add_copy_header_build_phase(spec.name, header_dir)
          files.each do |file|
            group.add_source_file(file, copy_phase)
          end
        end

        # Collect all header search paths
        user_header_search_paths.concat(spec.user_header_search_paths)
      end
      xcconfig.merge!('USER_HEADER_SEARCH_PATHS' => user_header_search_paths.sort.uniq.join(" "))
    end

    def copy_resources_script
      @copy_resources_script ||= Xcode::CopyResourcesScript.new(build_specifications.map { |spec| spec.expanded_resources }.flatten)
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
      xcodeproj.create_in(root)
      xcconfig.create_in(root)
      if @specification.generate_bridge_support?
        path = bridge_support_generator.create_in(root)
        copy_resources_script.resources << path.relative_path_from(config.project_pods_root)
      end
      copy_resources_script.create_in(root)

      build_specifications.each(&:post_install)
    end
  end
end
