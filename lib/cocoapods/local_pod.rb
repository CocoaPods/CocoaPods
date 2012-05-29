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

    # Method to add the specifications sharing the same top level
    # parent. With this information the local pod can determine the
    # paths to clean and avoid duplication in file processing.
    # Adding specifications is idempotent.
    def add_specification(spec)
      raise Informative, "[Local Pod] Attempt to add a specification from another pod" unless spec.top_level_parent == top_specification
      spec.activate_platform(platform)
      @specifications << spec unless @specifications.include?(spec)
    end

    def root
      @sandbox.root + top_specification.name
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

    # Installation methods

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

    # It deletes all the files identified by clean_files, then it removes
    # all the empty folders or symlinks.
    def clean
      clean_files.each { |path| FileUtils.rm_rf(path) }

      # Get all the directories. Then sort them from the longest
      # to the shortest, so a directory will be empty if its
      # subdirs where empty. We need to delete the symlinks because
      # it might prevent a bundle from being deleted
      dirs = Dir.glob(root + "**/*", File::FNM_DOTMATCH)
      dirs = dirs.reject { |d| d.end_with?('.', '..') || !File.directory?(d) }.sort_by(&:length).reverse
      dirs.each    { |d| FileUtils.rm_rf(d) if File.symlink?(d) || (Dir.entries(d) == %w[ . .. ]) }
    end

    # File attributes

    def prefix_header_file
      root + top_specification.prefix_header_file if top_specification.prefix_header_file
    end

    def source_files(relative = true)
      chained_expanded_paths(:source_files, :glob => '*.{h,m,mm,c,cpp}', :relative_to_sandbox => relative)
    end

    def header_files
      source_files.select { |f| f.extname == '.h' }
    end

    def resources(relative = true)
      chained_expanded_paths(:resources, :relative_to_sandbox => relative)
    end

    def clean_files
      all_files = Dir.glob(root + "**/*", File::FNM_DOTMATCH).map { |f| root + f }.reject { |p| p.directory? }
      all_files - used_files
    end

    def used_files
      source_files(false) + resources(false) + preserve_paths + [ readme_file, license_file, prefix_header_file ]
    end

    # TODO: implement case insensitive search
    def preserve_paths
      chained_expanded_paths(:preserve_paths) + expanded_paths(%w[ *.podspec notice* NOTICE* CREDITS* ])
    end

    def readme_file
      expanded_paths(%w[ README{*,.*} readme{*,.*} ]).first
    end

    def license_file
      if top_specification.license && top_specification.license[:file]
        root + top_specification.license[:file]
      else
        expanded_paths(%w[ LICENSE{*,.*} licence{*,.*} ]).first
      end
    end

    def license_text
      if (license_hash = top_specification.license)
        if (result = license_hash[:text])
          result
        elsif license_file
          result = IO.read(license_file)
        end
      end
    end

    def xcconfig
      specifications.map { |s| s.xcconfig }.reduce(:merge)
    end

    # Method used by documentation generator. It return the source files
    # of all the specs.
    def all_specs_public_header_files
      #TODO: merge with #221
      specs = top_specification.recursive_subspecs << top_specification
      specs.map { |s| expanded_paths(s.source_files, :glob => '*.{h}') }.compact.flatten.select { |f| f.extname == '.h' }.uniq
    end

    # Integration methods

    def link_headers
      copy_header_mappings.each do |namespaced_path, files|
        @sandbox.add_header_files(namespaced_path, files)
      end
    end

    def add_to_target(target)
      sources_files_by_specification.each do | spec, files |
        files.each do |file|
          # TODO: Xcodeproj::Project::Object::PBXNativeTarget#add_source_file is quite slow
          # The issus appears to be related to the find call in line 107.
          target.add_source_file(file, nil, spec.compiler_flags.strip)
        end
      end
    end

    def requires_arc?
      top_specification.requires_arc
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
    #
    # This is not overriden anymore in specification refactor and the code
    # Pod::Specification#copy_header_mapping can be moved here.
    def copy_header_mappings
      search_path_headers = header_files - headers_excluded_from_search_paths
      search_path_headers.inject({}) do |mappings, from|
        from_without_prefix = from.relative_path_from(relative_root)
        to = top_specification.header_dir + top_specification.copy_header_mapping(from_without_prefix)
        (mappings[to.dirname] ||= []) << from
        mappings
      end
    end

    # returns an hash where the source_files are groupped by specification.
    # If the same file is required by two specifications the one at the
    # higher level in the inheritance chain wins.
    def sources_files_by_specification
      files_by_spec   = {}
      processed_files = []
      specifications.sort_by { |s| s.name.length }.each do |spec|
        files = []
        expanded_paths(spec.source_files, :glob => '*.{h,m,mm,c,cpp}', :relative_to_sandbox => true).each do | file |
          files << file unless processed_files.include?(file)
        end
        files_by_spec[spec] = files
        processed_files    += files
      end
      files_by_spec
    end

    def headers_excluded_from_search_paths
      chained_expanded_paths(:exclude_header_search_paths, :glob => '*.h', :relative_to_sandbox => true)
    end

    def chained_expanded_paths(accessor, options = {})
      specifications.map { |s| expanded_paths(s.send(accessor), options) }.compact.flatten.uniq
    end

    def expanded_paths(patterns, options = {})
      raise Informative, "[Local Pod] Attempt to resolve paths for non existent pod." unless exists?

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
