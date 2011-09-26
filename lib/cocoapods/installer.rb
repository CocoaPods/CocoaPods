module Pod
  # TODO the static library needs an extra xcconfig which sets the values from issue #1.
  # Or we could edit the project.pbxproj file, but that seems like more work...
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

    def source_files
      source_files = {}
      build_specification_sets.each do |set|
        spec = set.specification
        source_files[spec.name] = []
        spec.source_files.each do |pattern|
          pattern = spec.pod_destroot + pattern
          pattern = pattern + '*.{h,m,mm,c,cpp}' if pattern.directory?
          pattern.glob.each do |file|
            source_files[spec.name] << file.relative_path_from(config.project_pods_root)
          end
        end
      end
      source_files
    end

    def grouped_source_files_for_spec(spec)
      grouped_files = {}
      spec.source_files.each do |pattern|
        pattern = spec.pod_destroot + pattern
        pattern = pattern + '*.{h,m,mm,c,cpp}' if pattern.directory?
        pattern.glob.each do |file|
          dir, _ = file.relative_path_from(spec.pod_destroot).split
          dir = dir.to_s
          if dir == "."
            dir = spec.name
          else
            if dir.split('/')[0] != spec.name
              dir = spec.name + '/' + dir
            end
          end
          
          grouped_files[dir.to_s] ||= []
          grouped_files[dir.to_s] << file.relative_path_from(config.project_pods_root)
        end
      end
      grouped_files
    end
    
    def xcconfig
      @xcconfig ||= Xcode::Config.new({
        # In a workspace this is where the static library headers should be found
        # We could also make this recursive, but let's let the user decide on that.
        'USER_HEADER_SEARCH_PATHS' => '"$(BUILT_PRODUCTS_DIR)/Pods"',
        # search the user headers
        'ALWAYS_SEARCH_USER_PATHS' => 'YES',
      })
    end

    def xcodeproj
      @xcodeproj ||= Xcode::Project.ios_static_library
    end

    def generate_project
      build_specification_sets.each do |set|
        xcodeproj.add_group(set.specification.name)
        xcconfig << {'USER_HEADER_SEARCH_PATHS' => "\"$(BUILT_PRODUCTS_DIR)/Pods/#{set.specification.name}\""}
        grouped_source_files_for_spec(set.specification).each do |path, files|
          phase_uuid = xcodeproj.add_copy_header_build_phase(set.specification.name, path)
          xcconfig << {'USER_HEADER_SEARCH_PATHS' => "\"$(BUILT_PRODUCTS_DIR)/Pods/#{path}\""}
          files.each do |file|
            xcodeproj.add_source_file(file, set.specification.name, phase_uuid)
          end
        end
        
        #puts "#{grouped_source_files_for_spec(set.specification)}"
        xcconfig << set.specification.xcconfig
      end
    end

    # TODO we need a spec that tests that all dependencies are first downloaded/installed
    # before #generate_project is called!
    def install!
      puts "Installing dependencies of: #{@specification.defined_in_file}" unless config.silent?
      build_specification_sets.each do |set|
         set.specification.install!
      end
      generate_project
      xcodeproj.create_in(config.project_pods_root)
      xcconfig.create_in(config.project_pods_root)
    end
  end
end
