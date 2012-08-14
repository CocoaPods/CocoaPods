module Pod

  # A {LocalPod} interfaces one or more specifications belonging to one pod
  # (a library) and their concrete instance in the file system.
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
  #     pod = LocalPod.new 'RestKit/Networking'
  #     pod.add_specification 'RestKit/UI'
  #
  # @note
  #   Unless otherwise specified in the name of the method the {LocalPod}
  #   returns absolute paths.
  #
  class LocalPod

    # @return [Specification] The specification that describes the pod.
    #
    attr_reader :top_specification

    # @return [Specification] The activated specifications of the pod.
    #
    attr_reader :specifications

    # @return [Sandbox] The sandbox where the pod is installed.
    #
    attr_reader :sandbox

    # @return [Platform] The platform that will be used to build the pod.
    #
    attr_reader :platform

    # @return [Boolean] Wether or not the pod has been downloaded in the
    #                   current install process and still needs its docs
    #                   generated and be cleaned.
    #
    attr_accessor :downloaded
    alias_method :downloaded?, :downloaded

    # @param [Specification] specification  The first activated specification
    #                                       of the pod.
    #
    # @param [Sandbox] sandbox              The sandbox where the files of the
    #                                       pod will be located.
    #
    # @param [Platform] platform            The platform that will be used to
    #                                       build the pod.
    #
    # @todo The local pod should be initialized with all the activated
    #       specifications passed as an array, in order to be able to cache the
    #       computed values. In other words, it should be immutable.
    #
    def initialize(specification, sandbox, platform)
      @top_specification, @sandbox, @platform = specification.top_level_parent, sandbox, platform
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
    #                  the pods comes from a local source.
    #
    def to_s
      top_specification.to_s
    end

    # @return [String] The name of the Pod.
    #
    def name
      top_specification.name
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

    def local?
      false
    end

    # @!group Cleaning

    # Deletes any path that is not used by the pod.
    #
    # @return [void]
    #
    def clean!
      clean_paths.each { |path| FileUtils.rm_rf(path) }
      @cleaned = true
    end

    # Finds the absolute paths, including hidden ones, of the files
    # that are not used by the pod and thus can be safely deleted.
    #
    # @return [Array<Strings>] The paths that can be deleted.
    #
    def clean_paths
      cached_used_paths = used_files
      files = Dir.glob(root + "**/*", File::FNM_DOTMATCH)

      files.reject! do |candidate|
        candidate.end_with?('.', '..') || cached_used_paths.any? do |path|
          path.include?(candidate) || candidate.include?(path)
        end
      end
      files
    end

    # @return [Array<String>] The absolute path of the files used by the pod.
    #
    def used_files
      files = [ source_files, resource_files, preserve_files, readme_file, license_file, prefix_header_file ]
      files.compact!
      files.flatten!
      files.map!{ |path| path.to_s }
      files
    end

    # @!group Files

    # @return [Array<Pathname>] The paths of the source files.
    #
    def source_files
      source_files_by_spec.values.flatten
    end

    # @return [Array<Pathname>] The *relative* paths of the source files.
    #
    def relative_source_files
      source_files.map{ |p| p.relative_path_from(@sandbox.root) }
    end

    # Finds the source files that every activated {Specification} requires.
    #
    # @note If the same file is required by two specifications the one at the
    #   higher level in the inheritance chain wins.
    #
    # @return [Hash{Specification => Array<Pathname>}] The files grouped by
    #   {Specification}.
    #
    def source_files_by_spec
      options = {:glob => '*.{h,m,mm,c,cpp}'}
      paths_by_spec(:source_files, options)
    end

    # @return [Array<Pathname>] The paths of the header files.
    #
    def header_files
      header_files_by_spec.values.flatten
    end

    # @return [Array<Pathname>] The *relative* paths of the source files.
    #
    def relative_header_files
      header_files.map{ |p| p.relative_path_from(@sandbox.root) }
    end

    # @return [Hash{Specification => Array<Pathname>}] The paths of the header
    #   files grouped by {Specification}.
    #
    def header_files_by_spec
      result = {}
      source_files_by_spec.each do |spec, paths|
        headers = paths.select { |f| f.extname == '.h' }
        result[spec] = headers unless headers.empty?
      end
      result
    end

    # @return [Hash{Specification => Array<Pathname>}] The paths of the header
    #   files grouped by {Specification} that should be copied in the public
    #   folder.
    #
    #   If a spec does not match any public header it means that all the
    #   header files (i.e. the build ones) are intended to be public.
    #
    def public_header_files_by_spec
      public_headers = paths_by_spec(:public_header_files, :glob => '*.h')
      build_headers  = header_files_by_spec

      result = {}
      specifications.each do |spec|
        if (public_h = public_headers[spec]) && !public_h.empty?
          result[spec] = public_h
        elsif (build_h = build_headers[spec]) && !build_h.empty?
          result[spec] = build_h
        end
      end
      result
    end

    # @return [Array<Pathname>] The paths of the resources.
    #
    def resource_files
      paths_by_spec(:resources).values.flatten
    end

    # @return [Array<Pathname>] The *relative* paths of the resources.
    #
    def relative_resource_files
      resource_files.map{ |p| p.relative_path_from(@sandbox.root) }
    end

    # @return [Pathname] The absolute path of the prefix header file
    #
    def prefix_header_file
      root + top_specification.prefix_header_file if top_specification.prefix_header_file
    end

    # @return [Array<Pathname>] The absolute paths of the files of the pod
    #   that should be preserved.
    #
    def preserve_files
      paths  = paths_by_spec(:preserve_paths).values
      paths += expanded_paths(%w[ *.podspec notice* NOTICE* CREDITS* ])
      paths.compact!
      paths.uniq!
      paths
    end

    # @return [Pathname] The automatically detected absolute path of the README
    #  file.
    #
    def readme_file
      expanded_paths(%w[ readme{*,.*} ]).first
    end

    # @return [Pathname] The absolute path of the license file from the
    #   specification or automatically detected.
    #
    def license_file
      if top_specification.license && top_specification.license[:file]
        root + top_specification.license[:file]
      else
        expanded_paths(%w[ licen{c,s}e{*,.*} ]).first
      end
    end

    # @return [String] The text of the license of the pod from the
    #  specification or from the license file.
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

    # Computes the paths of all the public headers of the pod including every
    # subspec (activated or not).
    # For this reason the pod must not be cleaned when calling this command.
    #
    # This method is used by {Generator::Documentation}.
    #
    # @raise [Informative] If the pod was cleaned.
    #
    # @return [Array<Pathname>] The path of all the public headers of the pod.
    #
    def documentation_headers
      if @cleaned
        raise Informative, "The pod is cleaned and cannot compute the " \
                           "header files, as some might have been deleted."
      end

      specs = [top_specification] + top_specification.recursive_subspecs
      source_files   = paths_by_spec(:source_files, { :glob => '*.{h}'}, specs)
      public_headers = paths_by_spec(:public_header_files,{ :glob => '*.{h}'}, specs)

      result = []
      specs.each do |spec|
        if (public_h = public_headers[spec]) && !public_h.empty?
          result += public_h
        elsif (source_f = source_files[spec]) && !source_f.empty?
          build_h = source_f.select { |f| f.extname == '.h' }
          result += build_h unless build_h.empty?
        end
      end
      result
    end

    # @!group Target integration

    # @return [void] Copies the pods headers to the sandbox.
    #
    def link_headers
      @sandbox.build_headers.add_search_path(headers_sandbox)
      @sandbox.public_headers.add_search_path(headers_sandbox)

      header_mappings(header_files_by_spec).each do |namespaced_path, files|
        @sandbox.build_headers.add_files(namespaced_path, files)
      end

      header_mappings(public_header_files_by_spec).each do |namespaced_path, files|
        @sandbox.public_headers.add_files(namespaced_path, files)
      end
    end

    # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
    #   The target to integrate.
    #
    # @return [void] Adds the pods source files to a given target.
    #
    def source_file_descriptions
      result = []
      source_files_by_spec.each do | spec, files |
        compiler_flags = spec.compiler_flags.strip
        files.each do |file|
          file = file.relative_path_from(@sandbox.root)
          desc = Xcodeproj::Project::PBXNativeTarget::SourceFileDescription.new(file, compiler_flags, nil)
          result << desc
        end
      end
      result
    end

    # @return Whether the pod requires ARC.
    #
    def requires_arc?
      top_specification.requires_arc
    end

    private

    # @return [Array<Pathname>] The implementation files
    # (the files the need to compiled) of the pod.
    #
    def implementation_files
      relative_source_files.select { |f| f.extname != '.h' }
    end

    # @return [Pathname] The path of the pod relative from the sandbox.
    #
    def relative_root
      root.relative_path_from(@sandbox.root)
    end

    # @return Hash{Pathname => [Array<Pathname>]} A hash containing the headers
    #   folders as the keys and the the absolute paths of the header files
    #   as the values.
    #
    # @todo this is being overridden in the RestKit 0.9.4 spec, need to do
    # something with that, and this method also still exists in Specification.
    #
    # @todo This is not overridden anymore in specification refactor and the
    #   code Pod::Specification#copy_header_mapping can be moved here.
    def header_mappings(files_by_spec)
      mappings = {}
      files_by_spec.each do |spec, paths|
        paths = paths - headers_excluded_from_search_paths
        paths.each do |from|
          from_relative = from.relative_path_from(root)
          to = headers_sandbox + (spec.header_dir) + spec.copy_header_mapping(from_relative)
          (mappings[to.dirname] ||= []) << from
        end
      end
      mappings
    end

    # @return <Pathname> The name of the folder where the headers of this pod
    #   will be namespaced.
    #
    def headers_sandbox
      @headers_sandbox ||= Pathname.new(top_specification.name)
    end

    # @return [<Pathname>] The relative path of the headers that should not be
    # included in the linker search paths.
    #
    def headers_excluded_from_search_paths
      options = { :glob => '*.h' }
      paths = paths_by_spec(:exclude_header_search_paths, options)
      paths.values.compact.uniq
    end

    # @!group Paths Patterns

    # The paths obtained by resolving the patterns of an attribute
    # groupped by spec.
    #
    # @param [Symbol] accessor The accessor to use to obtain the paths patterns.
    # @param [Hash] options (see #expanded_paths)
    #
    def paths_by_spec(accessor, options = {}, specs = nil)
      specs ||= specifications
      paths_by_spec   = {}
      processed_paths = []

      specs = specs.sort_by { |s| s.name.length }
      specs.each do |spec|
        paths = expanded_paths(spec.send(accessor), options)
        unless paths.empty?
          paths_by_spec[spec] = paths - processed_paths
          processed_paths += paths
        end
      end
      paths_by_spec
    end

    # Converts patterns of paths to the {Pathname} of the files present in the
    #   pod.
    #
    # @param [String, FileList, Array<String, Pathname>] patterns
    #   The patterns to expand.
    # @param [Hash] options
    #   The options to used for expanding the paths patterns.
    # @option options [String] :glob
    #   The pattern to use for globing directories.
    #
    # @raise [Informative] If the pod does not exists.
    #
    # @todo implement case insensitive search
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
        Pathname.glob(pattern, File::FNM_CASEFOLD)
      end.flatten
    end

    # A {LocalSourcedPod} is a {LocalPod} that interacts with the files of
    # a folder controlled by the users. As such this class does not alter
    # in any way the contents of the folder.
    #
    class LocalSourcedPod < LocalPod
      def downloaded?
        true
      end

      def create
        # No ops
      end

      def root
        Pathname.new(@top_specification.defined_in_file).dirname
      end

      def implode
        # No ops
      end

      def clean!
        # No ops
      end

      def to_s
        super + " [LOCAL]"
      end

      def local?
        true
      end
    end
  end
end
