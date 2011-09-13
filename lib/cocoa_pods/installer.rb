module Pod
  # TODO the static library needs an extra xcconfig which sets the values from issue #1.
  # Or we could edit the project.pbxproj file, but that seems like more work...
  class Installer
    def initialize(top_level_specification, pods_root)
      @top_level_specification, @pods_root = top_level_specification, pods_root
    end

    def dependent_specification_sets
      @dependent_specifications_sets ||= Resolver.new(@top_level_specification).resolve
    end

    def xcconfig
      @xcconfig ||= Xcode::Config.new({
        # in a workspace this is where the static library headers should be found
        'USER_HEADER_SEARCH_PATHS' => '$(BUILT_PRODUCTS_DIR)',
        # search the user headers
        'ALWAYS_SEARCH_USER_PATHS' => 'YES',
      })
    end

    def xproj
      @xproj ||= Xcode::Project.static_library
    end

    def install!
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
      puts "==> Creating Pods project files"
      dependent_specification_sets.each do |set|
        # In case the set is only part of other pods we don't need to build
        # the pod itself.
        next if set.only_part_of_other_pod?
        spec = set.specification
        spec.read(:source_files).each do |pattern|
          pattern = spec.pod_destroot + pattern
          pattern = pattern + '*.{h,m,mm,c,cpp}' if pattern.directory?
          Dir.glob(pattern.to_s).each do |file|
            file = Pathname.new(file)
            file = file.relative_path_from(@pods_root)
            xproj.add_source_file(file)
          end
        end
        xcconfig << spec.read(:xcconfig)
      end
    end

    def write_files!
      xproj.create_in(@pods_root)
      xcconfig.create_in(@pods_root)
    end
  end
end
