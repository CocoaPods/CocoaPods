module Pod

  # A {LocalPod} interfaces one or more specifications belonging to one pod (a
  # library) and their concrete instance in the file system.
  #
  # The {LocalPod} is responsible for orchestrating the activated
  # specifications of a single pod. Specifically, it keeps track of the
  # activated specifications and handles issues related to duplicates
  # files.
  # Inheritance logic belongs to the {Specification} class.
  #
  # The activated specifications are used to compute the paths that can be
  # safely cleaned by the pod.
  #
  # @example
  #
  #     pod = LocalPod.new 'RestKit/Networking'
  #     pod.add_specification 'RestKit/UI'
  #
  class LocalPod

    # @return {Specification} The specification that describes the pod.
    #
    attr_reader :top_specification

    # @return {Specification} The activated specifications of the pod.
    #
    attr_reader :specifications

    # @return {Sandbox} The sandbox where the pod is installed.
    #
    attr_reader :sandbox

    # @param [Specification] specification the first activated specification
    #   of the pod.
    # @param [Sandbox] sandbox The sandbox where the files of the pod will be
    #   located.
    # @param [Platform] platform The platform that will be used to build the
    #   pod.
    #
    # @todo The local pod should be initialized with all the activated
    #   specifications passed as an array, in order to be able to cache the
    #   computed values. In other words, it should be immutable.
    #
    def initialize(specification, sandbox, platform)
      @top_specification, @sandbox = specification.top_level_parent, sandbox
      @top_specification.activate_platform(platform)
      @specifications = [] << specification
    end

    # Initializes a local pod from the top specification of a podspec file.
    #
    # @return [LocalPod] A new local pod.
    #
    def self.from_podspec(podspec, sandbox, platform)
      new(Specification.from_file(podspec), sandbox, platform)
    end

    # Activates a specification or subspecs for the pod.
    # Adding specifications is idempotent.
    #
    # @param {Specification} spec The specification to add to the pod.
    #
    # @raise {Informative} If the specification is not part of the same pod.
    #
    def add_specification(spec)
      unless spec.top_level_parent == top_specification
        raise Informative,
          "[Local Pod] Attempt to add a specification from another pod"
      end
      spec.activate_platform(platform)
      @specifications << spec unless @specifications.include?(spec)
    end

    # @return [Pathname] The root directory of the pod
    #
    def root
      @sandbox.root + top_specification.name
    end

    # @return [String] A string representation of the pod which indicates if
    # the pods comes from a local source.
    #
    def to_s
      result = top_specification.to_s
      result << " [LOCAL]" if top_specification.local?
      result
    end

    # @return [String] The name of the Pod.
    #
    def name
      top_specification.name
    end

    # @return [Platform] The platform that will be used to build the pod.
    #
    def platform
      top_specification.active_platform
    end

    # @!group Installation

    # Creates the root path of the pod.
    #
    # @return [void]
    #
    def create
      root.mkpath unless exists?
    end

    # Whether the root path of the pod exists.
    #
    def exists?
      root.exist?
    end

    # Executes a block in the root directory of the Pod.
    #
    # @return [void]
    #
    def chdir(&block)
      create
      Dir.chdir(root, &block)
    end

    # Deletes the pod from the file system.
    #
    # @return [void]
    #
    def implode
      root.rmtree if exists?
    end

    # @!group Cleaning

    # Deletes any path that is not used by the pod.
    #
    # @return [void]
    #
    def clean
      clean_paths.each { |path| FileUtils.rm_rf(path) }
    end

    # Finds the absolute paths, including hidden ones, of the files
    # that are not used by the pod and thus can be safely deleted.
    #
    # @return [Array<Strings>] The paths that can be deleted.
    #
    def clean_paths
      cached_used_paths = used_paths.map{ |path| path.to_s }
      files = Dir.glob(root + "**/*", File::FNM_DOTMATCH)

      files.reject! do |candidate|
        candidate.end_with?('.', '..') || cached_used_paths.any? do |path|
          path.include?(candidate) || candidate.include?(path)
        end
      end
      files
    end

    # @return [Array<Pathname>] The paths of the files used by the pod.
    #
    def used_paths
      files = [ source_files(false),
                resources(false),
                preserve_paths,
                readme_file,
                license_file,
                prefix_header_file ]
      files.compact!
      files.flatten!
      files
    end

    # @!group Files

    # @param [Boolean] relative Whether the paths should be returned relative
    #  to the sandbox.
    #
    # @return [Array<Pathname>] The paths of the source files.
    #
    def source_files(relative = true)
      chained_expanded_paths(:source_files, :glob => '*.{h,m,mm,c,cpp}', :relative_to_sandbox => relative)
    end

    # @param (see #source_files)
    #
    # @return [Array<Pathname>] The paths of the header files.
    #
    def header_files
      source_files.select { |f| f.extname == '.h' }
    end

    # @param (see #source_files)
    #
    # @return [Array<Pathname>] The paths of the resources.
    #
    def resources(relative = true)
      chained_expanded_paths(:resources, :relative_to_sandbox => relative)
    end

    # @return [Pathname] The absolute path of the prefix header file
    #
    def prefix_header_file
      root + top_specification.prefix_header_file if top_specification.prefix_header_file
    end

    # @return [Array<Pathname>] The absolute paths of the files of the pod
    #   that should be preserved.
    #
    def preserve_paths
      chained_expanded_paths(:preserve_paths) + expanded_paths(%w[ *.podspec notice* NOTICE* CREDITS* ])
    end

    # @return [Pathname] The automatically detected path of the README
    #  file.
    #
    def readme_file
      expanded_paths(%w[ README{*,.*} readme{*,.*} ]).first
    end

    # @return [Pathname] The absolute path of the license file from the
    #   specification or automatically detected.
    #
    def license_file
      if top_specification.license && top_specification.license[:file]
        root + top_specification.license[:file]
      else
        expanded_paths(%w[ LICENSE{*,.*} licence{*,.*} ]).first
      end
    end

    # @return [String] The text of the license of the pod from the
    #   specification or from the license file.
    #
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

    # @!group Target integration

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

    # @todo this is being overridden in the RestKit 0.9.4 spec, need to do
    # something with that, and this method also still exists in Specification.
    #
    # @todo This is not overridden anymore in specification refactor and the code
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

    # Finds the source files that every activate {Specification} requires.
    #
    # @note The paths of the files are relative to the sandbox.
    # @note If the same file is required by two specifications the one at the higher level in the inheritance chain wins.
    #
    # @return [Hash{Specification => Array<Pathname>}] The files grouped by {Specification}.
    #
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

    # @todo merge with #221
    #
    def headers_excluded_from_search_paths
      chained_expanded_paths(:exclude_header_search_paths, :glob => '*.h', :relative_to_sandbox => true)
    end


    # @!group File Patterns

    # Find all the paths patterns of a each activated specifications and converts them to the actual paths present in the pod.
    #
    # @return Array<Pathname> A list of the paths.
    #
    def chained_expanded_paths(accessor, options = {})
      specifications.map { |s| expanded_paths(s.send(accessor), options) }.compact.flatten.uniq
    end

    # Converts patterns of paths to the {Pathname} of the files present in the pod.
    #
    # @todo implement case insensitive search
    #
    # @param [String, FileList, Array<String, Pathname>] patterns The patterns
    #   to expand.
    # @param [Hash] options the options to used for expanding the paths patterns.
    # @option options [String]  :glob The pattern to use for globing directories.
    # @option options [Boolean] :relative_to_sandbox Whether the paths should
    #   be returned relative to the sandbox.
    #
    # @raise [Informative] If the pod does not exists.
    #
    # @return [Array<Pathname>] A list of the paths.
    #
    def expanded_paths(patterns, options = {})
      unless exists?
        raise Informative, "[Local Pod] Attempt to resolve paths for nonexistent pod.\n" \
                           "\tSpecifications: #{@specifications.inspect}\n" \
                           "\t      Patterns: #{patterns.inspect}\n" \
                           "\t       Options: #{options.inspect}"
      end

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
