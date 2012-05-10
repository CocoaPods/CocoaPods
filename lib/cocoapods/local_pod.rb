module Pod
  class LocalPod
    attr_reader :top_specification, :specifications
    # TODO: fix accross the app
    alias :specification :top_specification
    attr_reader :sandbox

    def initialize(specification, sandbox, platform)
      @top_specification, @sandbox = specification, sandbox
      @top_specification.activate_platform(platform)
      @specifications = [] << specification
    end

    def self.from_podspec(podspec, sandbox, platform)
      new(Specification.from_file(podspec), sandbox, platform)
    end

    def root
      @sandbox.root + top_specification.name
    end

    # Adding specifications is idempotent
    def add_specification(spec)
      raise Informative, "[Local Pod] Attempt to add a specification from another pod" unless spec.top_level_parent == top_specification
      spec.activate_platform(platform)
      @specifications << spec unless @specifications.include?(spec)
    end

    def subspecs
      specifications.reject{|s| s.parent.nil? }
    end

    def to_s
      result = top_specification.to_s
      # result << " [LOCAL]" if top_specification.local?
      result
    end

    def name
      top_specification.name
    end

    def platform
      top_specification.active_platform
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
      # TODO: nuke everything that is not used
      # clean_paths.each { |path| FileUtils.rm_rf(path) }
    end

    def prefix_header_file
      if prefix_header = top_specification.prefix_header_file
        @sandbox.root + top_specification.name + prefix_header
      end
    end

    def source_files
      chained_expanded_paths(:source_files, :glob => '*.{h,m,mm,c,cpp}', :relative_to_sandbox => true)
    end

    def absolute_source_files
      chained_expanded_paths(:source_files, :glob => '*.{h,m,mm,c,cpp}')
    end

    def clean_paths
      # TODO: delete
      # chained_expanded_paths(:clean_paths)
    end

    def resources
      chained_expanded_paths(:resources, :relative_to_sandbox => true)
    end

    def header_files
      source_files.select { |f| f.extname == '.h' }
    end

    def link_headers
      copy_header_mappings.each do |namespaced_path, files|
        @sandbox.add_header_files(namespaced_path, files)
      end
    end

    def readme_file
      expanded_paths('README.*', options = {})
    end

    def license
      #TODO: merge with the work of will and return the text
      expanded_paths(%w[ LICENSE licence.txt ], options = {})
    end

    def add_to_target(target)
      implementation_files.each do |file|
        target.add_source_file(file, nil, specification.compiler_flags.strip)
      end
    end

    def requires_arc?
      specification.requires_arc
    end

    def dependencies
      specification.dependencies
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

    def chained_expanded_paths(accessor, options = {})
      specifications.map { |s| expanded_paths(s.send(accessor), options) }.compact.reduce(:+).uniq
    end

    def expanded_paths(patterns, options = {})
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
