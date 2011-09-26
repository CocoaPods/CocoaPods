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
      source_files.each do |group, files|
        xcodeproj.add_group(group)
        files.each do |file|
          xcodeproj.add_source_file(file, group)
        end
      end
      build_specification_sets.each do |set|
        xcconfig << set.specification.xcconfig
        xcconfig << {'USER_HEADER_SEARCH_PATHS' => "\"$(BUILT_PRODCUTS_DIR)/Pods/#{set.specification.name}\""}
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
