module Pod
  class LocalPod
    attr_reader :top_specification, :specifications
    attr_reader :sandbox

    def initialize(specification, sandbox, platform)
      @top_specification, @sandbox = specification.top_level_parent, sandbox
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
      result << " [LOCAL]" if top_specification.local?
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
      clean_paths.each { |path| FileUtils.rm_rf(path) }

      # remove empty diretories
      Dir.glob("#{root}/**/{*,.*}").
        sort_by(&:length).reverse.            # Clean the deepest paths first to determine if the containing folders are empty
        reject { |d| d =~ /\/\.\.?$/ }.       # Remove the `.` and `..` paths
        select { |d| File.directory?(d) }.    # Get only directories or symlinks to directories
        each do |d|
          FileUtils.rm_rf(d) if File.symlink?(d) || (Dir.entries(d) == %w[ . .. ]) # Remove the symlink and the empty dirs
        end
    end

    def prefix_header_file
      if prefix_header = top_specification.prefix_header_file
        @sandbox.root + top_specification.name + prefix_header
      end
    end

    def source_files(relative = true)
      chained_expanded_paths(:source_files, :glob => '*.{h,m,mm,c,cpp}', :relative_to_sandbox => relative)
    end

    def resources(relative = true)
      chained_expanded_paths(:resources, :relative_to_sandbox => relative)
    end

    def clean_paths
      expanded_paths('**/{*,.*}').reject { |p| p.directory? } - used_files
    end

    def used_files
      source_files(false) + resources(false) + [ readme_file, license_file, prefix_header_file ] + preserve_paths
    end

    def readme_file
      expanded_paths(%w[README* readme*]).first
    end

    def license_file
      expanded_paths(%w[ LICENSE* licence* ]).first
    end

    def preserve_paths
      chained_expanded_paths(:preserve_paths) + expanded_paths(%w[ *.podspec notice* NOTICE* ])
    end

    def header_files
      source_files.select { |f| f.extname == '.h' }
    end

    def link_headers
      copy_header_mappings.each do |namespaced_path, files|
        @sandbox.add_header_files(namespaced_path, files)
      end
    end

    def xcconfig
      specifications.map { |s| s.xcconfig }.reduce(:merge)
    end

    #TODO: fix
    def add_to_target(target)
      implementation_files.each do |file|
        # TODO: respect the compiler flags of each subspec
        target.add_source_file(file, nil, top_specification.compiler_flags.strip)
      end
    end


    def requires_arc?
      top_specification.requires_arc
    end

    def dependencies
      top_specification.dependencies
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
        to = top_specification.header_dir + top_specification.copy_header_mapping(from_without_prefix)
        (mappings[to.dirname] ||= []) << from
        mappings
      end
    end

    def chained_expanded_paths(accessor, options = {})
      specifications.map { |s| expanded_paths(s.send(accessor), options) }.compact.flatten.uniq
    end

    def expanded_paths(patterns, options = {})
      patterns = [ patterns ] if patterns.is_a? String
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
