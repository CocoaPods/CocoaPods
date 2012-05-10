module Pod
  class LocalPod
    attr_reader :specification
    attr_reader :sandbox
    attr_reader :platform

    def initialize(specification, sandbox, platform)
      @specification, @sandbox, @platform = specification, sandbox, platform
    end

    def self.from_podspec(podspec, sandbox, platform)
      new(Specification.from_file(podspec), sandbox, platform)
    end

    def root
      @sandbox.root + specification.name
    end

    def to_s
      if specification.local?
        "#{specification} [LOCAL]"
      else
        specification.to_s
      end
    end

    def name
      specification.name
    end

    def create
      root.mkpath unless exists?
    end

    def exists?
      root.exist?
    end

    def chdir(&block)
      create
      Dir.chdir(root, &block)
    end

    def implode
      root.rmtree if exists?
    end

    def clean
      clean_paths.each { |path| FileUtils.rm_rf(path) }
    end

    def prefix_header_file
      if prefix_header = specification.prefix_header_file
        @sandbox.root + specification.name + prefix_header
      end
    end

    def source_files
      expanded_paths(specification.source_files, :glob => '*.{h,m,mm,c,cpp}', :relative_to_sandbox => true)
    end

    def absolute_source_files
      expanded_paths(specification.source_files, :glob => '*.{h,m,mm,c,cpp}')
    end

    def clean_paths
      expanded_paths(specification.clean_paths)
    end

    def resources
      expanded_paths(specification.resources, :relative_to_sandbox => true)
    end

    def header_files
      source_files.select { |f| f.extname == '.h' }
    end

    def public_header_files
      if specification.public_header_files[@platform.name]
        expanded_paths(specification.public_header_files, :glob => '*.h', :relative_to_sandbox => true)
      else
        header_files
      end
    end

    def link_headers
      copy_header_mappings.each do |namespaced_path, files|
        @sandbox.build_header_storage.add_files(namespaced_path, files)
      end
      copy_public_header_mappings.each do |namespaced_path, files|
        @sandbox.public_header_storage.add_files(namespaced_path, files)
      end
    end

    def add_to_target(target)
      implementation_files.each do |file|
        target.add_source_file(file, nil, specification.compiler_flags[@platform.name].strip)
      end
    end

    def requires_arc?
      specification.requires_arc
    end

    def dependencies
      specification.dependencies[@platform.name]
    end

    private

    def implementation_files
      source_files.select { |f| f.extname != '.h' }
    end

    def relative_root
      root.relative_path_from(@sandbox.root)
    end

    # TODO this is being overriden in the RestKit 0.9.4 spec, need to do
    # something with that, and this method also still exists in Specification.
    def copy_header_mappings
      header_files.inject({}) do |mappings, from|
        from_without_prefix = from.relative_path_from(relative_root)
        to = specification.header_dir + specification.copy_header_mapping(from_without_prefix)
        (mappings[to.dirname] ||= []) << from
        mappings
      end
    end

    # TODO comment about copy_header_mappings may well apply to this method as well
    def copy_public_header_mappings
      public_header_files.inject({}) do |mappings, from|
        from_without_prefix = from.relative_path_from(relative_root)
        to = specification.header_dir + specification.copy_header_mapping(from_without_prefix)
        (mappings[to.dirname] ||= []) << from
        mappings
      end
    end

    def expanded_paths(platforms_with_patterns, options = {})
      patterns = platforms_with_patterns.is_a?(Hash) ? platforms_with_patterns[@platform.name] : platforms_with_patterns
      patterns.map do |pattern|
        pattern = root + pattern

        if pattern.directory? && options[:glob]
          pattern += options[:glob]
        end

        pattern.glob.map do |file|
          if options[:relative_to_sandbox]
            file.relative_path_from(@sandbox.root)
          else
            file
          end
        end
      end.flatten
    end
  end
end
