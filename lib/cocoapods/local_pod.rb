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
    autoload :DirList, 'cocoapods/local_pod/dir_list'

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

    def dir_list
      @dir_list ||= DirList.new(root)
    end

    # @return [String] A string representation of the pod which indicates if
    #                  the pods comes from a local source or has a preferred
    #                  dependency.
    #
    def to_s
      s =  top_specification.to_s
      s << " defaulting to #{top_specification.preferred_dependency} subspec" if top_specification.preferred_dependency
      s
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
      dir_list.read_file_system
    end

    # Finds the absolute paths, including hidden ones, of the files
    # that are not used by the pod and thus can be safely deleted.
    #
    # @return [Array<Strings>] The paths that can be deleted.
    #
    # @note Implementation detail: Don't use Dir#glob as there is an
    #       unexplained issue (#568, #572 and #602).
    #
    def clean_paths
      cached_used = used_files
      files = Pathname.glob(root + "**/*", File::FNM_DOTMATCH | File::FNM_CASEFOLD).map(&:to_s)

      files.reject! do |candidate|
        candidate.end_with?('.', '..') || cached_used.any? do |path|
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

    # @return [Pathname] Returns the relative path from the sandbox.
    #
    # @note If the two abosule paths don't share the same root directory an
    # extra `../` is added to the result of {Pathname#relative_path_from}
    #
    #     path = Pathname.new('/Users/dir')
    #     @sandbox
    #     #=> Pathname('/tmp/CocoaPods/Lint/Pods')
    #
    #     p.relative_path_from(@sandbox
    #     #=> '../../../../Users/dir'
    #
    #     relativize_from_sandbox(path)
    #     #=> '../../../../../Users/dir'
    #
    def relativize_from_sandbox(path)
      result = path.relative_path_from(@sandbox.root)
      result = Pathname.new('../') + result unless @sandbox.root.to_s.split('/')[1] == path.to_s.split('/')[1]
      result
    end

    # @return [Array<Pathname>] The paths of the source files.
    #
    def source_files
      source_files_by_spec.values.flatten
    end

    # @return [Array<Pathname>] The *relative* paths of the source files.
    #
    def relative_source_files
      source_files.map{ |p| relativize_from_sandbox(p) }
    end

    def relative_source_files_by_spec
      result = {}
      source_files_by_spec.each do |spec, paths|
        result[spec] = paths.map{ |p| relativize_from_sandbox(p) }
      end
      result
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
      options = {:glob => '*.{h,hpp,hh,m,mm,c,cpp}'}
      @source_files_by_spec ||= paths_by_spec(:source_files, '*.{h,hpp,hh,m,mm,c,cpp}')
    end

    # @return [Array<Pathname>] The paths of the header files.
    #
    def header_files
      header_files_by_spec.values.flatten
    end

    # @return [Array<Pathname>] The *relative* paths of the source files.
    #
    def relative_header_files
      header_files.map{ |p| relativize_from_sandbox(p) }
    end

    # @return [Hash{Specification => Array<Pathname>}] The paths of the header
    #   files grouped by {Specification}.
    #
    def header_files_by_spec
      result = {}
      source_files_by_spec.each do |spec, paths|
        headers = paths.select { |f| f.extname == '.h' || f.extname == '.hpp' || f.extname == '.hh' }
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
      public_headers = paths_by_spec(:public_header_files, '*.{h,hpp,hh}')
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
      resource_files.map{ |p| relativize_from_sandbox(p) }
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
      unless @license_file
        if top_specification.license && top_specification.license[:file]
          @license_file = root + top_specification.license[:file]
        else
          @license_file = expanded_paths(%w[ licen{c,s}e{*,.*} ]).first
        end
      end
      @license_file
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
      source_files   = paths_by_spec(:source_files, '*.{h}', specs)
      public_headers = paths_by_spec(:public_header_files, '*.{h}', specs)

      result = []
      specs.each do |spec|
        if (public_h = public_headers[spec]) && !public_h.empty?
          result += public_h
        elsif (source_f = source_files[spec]) && !source_f.empty?
          build_h = source_f.select { |f| f.extname == '.h' || f.extname == '.hpp' || f.extname == '.hh' }
          result += build_h unless build_h.empty?
        end
      end
      result
    end

    # @!group Xcodeproj integration

    # Adds the file references, to the given `Pods.xcodeproj` project, for the
    # source files of the pod. The file references are grouped by specification
    # and stored in {#file_references_by_spec}.
    #
    # @note If the pod is locally sourced the file references are stored in the
    #       `Local Pods` group otherwise they are stored in the `Pods` group.
    #
    # @return [void]
    #
    def add_file_references_to_project(project)
      @file_references_by_spec = {}
      parent_group = local? ? project.local_pods : project.pods

      relative_source_files_by_spec.each do |spec, paths|
        group = project.add_spec_group(spec.name, parent_group)
        file_references = []
        paths.each do |path|
          file_references << group.new_file(path)
        end
        @file_references_by_spec[spec] = file_references
      end
    end

    # @return [Hash{Specification => Array<PBXFileReference>}] The file
    #   references of the pod in the `Pods.xcodeproj` project.
    #
    attr_reader :file_references_by_spec

    # Adds a build file for each file reference to a given target taking into
    # account the compiler flags of the corresponding specification.
    #
    # @raise If the {#add_file_references_to_project} was not called before of
    #        calling this method.
    #
    # @return [void]
    #
    def add_build_files_to_target(target)
      unless file_references_by_spec
        raise Informative, "Local Pod needs to add the file references to the " \
                           "project before adding the build files to the target."
      end
      file_references_by_spec.each do |spec, file_reference|
        target.add_file_references(file_reference, spec.compiler_flags.strip)
      end
    end

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

    # @return Whether the pod requires ARC.
    #
    # TODO: this should be not used anymore.
    #
    def requires_arc?
      top_specification.requires_arc
    end

    private

    # @return [Array<Pathname>] The implementation files
    # (the files the need to compiled) of the pod.
    #
    def implementation_files
      relative_source_files.reject { |f| f.extname == '.h' ||  f.extname == '.hpp' || f.extname == '.hh' }
    end

    # @return [Pathname] The path of the pod relative from the sandbox.
    #
    def relative_root
      root.relative_path_from(@sandbox.root)
    end

    # @return Hash{Pathname => [Array<Pathname>]} A hash containing the headers
    #   folders as the keys and the absolute paths of the header files
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
        dir = spec.header_dir ? (headers_sandbox + spec.header_dir) : headers_sandbox
        paths.each do |from|
          from_relative = from.relative_path_from(root)
          to = dir + spec.copy_header_mapping(from_relative)
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
      paths = paths_by_spec(:exclude_header_search_paths, '*.{h,hpp,hh}')
      paths.values.compact.uniq
    end

    # @!group Paths Patterns

    # The paths obtained by resolving the patterns of an attribute
    # grouped by spec.
    #
    # @param [Symbol] accessor The accessor to use to obtain the paths patterns.
    #
    # @param [Hash] options (see #expanded_paths)
    #
    def paths_by_spec(accessor, dir_pattern = nil, specs = nil)
      specs ||= specifications
      paths_by_spec   = {}
      processed_paths = []

      specs = specs.sort_by { |s| s.name.length }
      specs.each do |spec|
        paths = expanded_paths(spec.send(accessor), dir_pattern, spec.excluded_patterns)
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
    def expanded_paths(patterns, dir_pattern = nil, exclude_patterns = nil)
      unless exists?
        raise Informative, "[Local Pod] Attempt to resolve paths for nonexistent pod.\n" \
                           "\tSpecifications: #{@specifications.inspect}\n" \
                           "\t      Patterns: #{patterns.inspect}"
      end

      # Noticeable impact on performance
      return [] if patterns.empty?

      patterns = [ patterns ] if patterns.is_a?(String)
      file_lists = patterns.select { |p| p.is_a?(FileList) }
      glob_patterns = patterns - file_lists

      result = []

      result << dir_list.glob(glob_patterns, dir_pattern, exclude_patterns)

      result << file_lists.map do |file_list|
        file_list.prepend_patterns(root)
        file_list.glob
      end

      result.flatten.compact.uniq
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
        @root ||= Pathname.new(@top_specification.source[:local]).expand_path
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
  end # LocalPod
end # Pod
