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
      source_files = []
      build_specification_sets.each do |set|
        spec = set.specification
        spec.read(:source_files).each do |pattern|
          pattern = spec.pod_destroot + pattern
          pattern = pattern + '*.{h,m,mm,c,cpp}' if pattern.directory?
          pattern.glob.each do |file|
            source_files << file.relative_path_from(config.project_pods_root)
          end
        end
      end
      source_files
    end

    def xcconfig
      @xcconfig ||= Xcode::Config.new({
        # in a workspace this is where the static library headers should be found
        'USER_HEADER_SEARCH_PATHS' => '$(BUILT_PRODUCTS_DIR)',
        # search the user headers
        'ALWAYS_SEARCH_USER_PATHS' => 'YES',
      })
    end

    def xcodeproj
      @xcodeproj ||= Xcode::Project.ios_static_library
    end

    def install!
      unless config.silent?
        puts "Installing dependencies defined in: #{@specification.defined_in_file}"
      end
      install_dependent_specifications!
      generate_project
      write_files!
    end

    def install_dependent_specifications!
      dependent_specification_sets.each do |set|
        # In case the set is only part of other pods we don't need to install
        # the pod itself.
        next if set.only_part_of_other_pod?
        set.specification.install!
      end
    end

    def generate_project
      puts "==> Creating Pods project files" unless config.silent?
      source_files.each { |file| xcodeproj.add_source_file(file) }
      build_specification_sets.each do |set|
        xcconfig << set.specification.read(:xcconfig)
      end
    end

    def write_files!
      xcodeproj.create_in(config.project_pods_root)
      xcconfig.create_in(config.project_pods_root)
    end
  end
end
