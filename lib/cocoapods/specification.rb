module Pod
  def self._eval_podspec(path)
    eval(path.read, nil, path.to_s)
  end

 class Specification
    autoload :Set, 'cocoapods/specification/set'

    def self.from_podfile(path)
      if path.exist?
        spec = new
        spec.instance_eval(path.read)
        spec.defined_in_file = path
        spec
      end
    end

    def self.from_podspec(path)
      spec = Pod._eval_podspec(path)
      spec.defined_in_file = path
      spec
    end

    attr_accessor :defined_in_file

    def initialize
      @dependencies = []
      @xcconfig = Xcode::Config.new
      yield self if block_given?
    end

    # Attributes

    attr_accessor :name
    attr_accessor :homepage
    attr_accessor :description
    attr_accessor :source

    attr_reader :version
    def version=(version)
      @version = Version.new(version)
    end

    def authors=(*names_and_email_addresses)
      list = names_and_email_addresses.flatten
      unless list.first.is_a?(Hash)
        authors = list.last.is_a?(Hash) ? list.pop : {}
        list.each { |name| authors[name] = nil }
      end
      @authors = authors || list.first
    end
    alias_method :author=, :authors=
    attr_reader :authors


    def summary=(summary)
      @summary = summary
      @description ||= summary
    end
    attr_reader :summary

    def part_of=(*name_and_version_requirements)
      self.part_of_dependency = *name_and_version_requirements
      @part_of.only_part_of_other_pod = true
    end
    attr_reader :part_of

    def part_of_dependency=(*name_and_version_requirements)
      @part_of = dependency(*name_and_version_requirements)
    end

    def source_files=(*patterns)
      @source_files = patterns.flatten.map { |p| Pathname.new(p) }
    end
    attr_reader :source_files

    def dependency(*name_and_version_requirements)
      name, *version_requirements = name_and_version_requirements.flatten
      dep = Dependency.new(name, *version_requirements)
      @dependencies << dep
      dep
    end
    attr_reader :dependencies

    def xcconfig=(hash)
      @xcconfig.merge!(hash)
    end
    attr_reader :xcconfig

    def frameworks=(*frameworks)
      frameworks.unshift('')
      self.xcconfig = { 'OTHER_LDFLAGS' => frameworks.join(' -framework ').strip }
    end
    alias_method :framework=, :frameworks=

    def libraries=(*libraries)
      libraries.unshift('')
      self.xcconfig = { 'OTHER_LDFLAGS' => libraries.join(' -l ').strip }
    end
    alias_method :library=, :libraries=

    def header_dir=(dir)
      @header_dir = Pathname.new(dir)
    end
    def header_dir
      @header_dir || pod_destroot_name
    end

    attr_accessor :requires_arc

    attr_writer :compiler_flags
    def compiler_flags
      flags = "#{@compiler_flags} "
      flags << '-fobj-arc' if @requires_arc
      flags
    end

    # Not attributes

    include Config::Mixin

    def ==(other)
      self.class === other &&
        @name && @name == other.name &&
          @version && @version == other.version
    end

    def dependency_by_name(name)
      @dependencies.find { |d| d.name == name }
    end

    def part_of_specification_set
      if @part_of
        Set.by_specification_name(@part_of.name)
      end
    end

    # Returns the specification for the pod that this pod's source is a part of.
    def part_of_specification
      (set = part_of_specification_set) && set.specification
    end

    def pod_destroot
      return if from_podfile?
      if part_of_other_pod?
        part_of_specification.pod_destroot
      else
        config.project_pods_root + @name
      end
    end

    def pod_destroot_name
      if root = pod_destroot
        root.basename
      end
    end

    def part_of_other_pod?
      !@part_of.nil?
    end

    def from_podfile?
      @name.nil? && @version.nil?
    end

    # Returns all source files of this pod including header files.
    def expanded_source_files
      files = []
      source_files.each do |pattern|
        pattern = pod_destroot + pattern
        pattern = pattern + '*.{h,m,mm,c,cpp}' if pattern.directory?
        pattern.glob.each do |file|
          files << file.relative_path_from(config.project_pods_root)
        end
      end
      files
    end

    def implementation_files
      expanded_source_files.select { |f| f.extname != '.h' }
    end

    # Returns only the header files of this pod.
    def header_files
      expanded_source_files.select { |f| f.extname == '.h' }
    end

    # This method takes a header path and returns the location it should have
    # in the pod's header dir.
    #
    # By default all headers are copied to the pod's header dir without any
    # namespacing. You can, however, override this method in the podspec, or
    # copy_header_mappings for full control.
    def copy_header_mapping(from)
      from.basename
    end

    # See copy_header_mapping.
    def copy_header_mappings
      header_files.inject({}) do |mappings, from|
        from_without_prefix = from.relative_path_from(pod_destroot_name)
        to = header_dir + copy_header_mapping(from_without_prefix)
        (mappings[to.dirname] ||= []) << from
        mappings
      end
    end

    # Returns a list of search paths where the pod's headers can be found. This
    # includes the pod's header dir root and any other directories that might
    # have been added by overriding the copy_header_mapping/copy_header_mappings
    # methods.
    def user_header_search_paths
      dirs = [header_dir] + copy_header_mappings.keys
      dirs.map { |dir| %{"$(BUILT_PRODUCTS_DIR)/Pods/#{dir}"} }
    end

    def to_s
      if from_podfile?
        "podfile at `#{@defined_in_file}'"
      else
        "`#{@name}' version `#{@version}'"
      end
    end

    def inspect
      "#<#{self.class.name} for #{to_s}>"
    end

    def validate!
      attrs = []
      attrs << "`name'"                       unless @name
      attrs << "`version'"                    unless @version
      attrs << "`summary'"                    unless @summary
      attrs << "`homepage'"                   unless @homepage
      attrs << "`author(s)'"                  unless @authors
      attrs << "either `source' or `part_of'" unless @source || @part_of
      attrs << "`source_files'"               unless @source_files
      unless attrs.empty?
        raise Informative, "The following required " \
          "#{attrs.size == 1 ? 'attribute is' : 'attributes are'} " \
          "missing: #{attrs.join(", ")}"
      end
    end

    # Install and download hooks

    # Places the activated specification in the project's pods directory.
    #
    # Override this if you need to perform work before or after activating the
    # pod. Eg:
    #
    #   Pod::Spec.new do
    #     def install!
    #       # pre-install
    #       super
    #       # post-install
    #     end
    #   end
    def install!
      puts "==> Installing: #{self}" unless config.silent?
      config.project_pods_root.mkpath
      require 'fileutils'
      FileUtils.cp(@defined_in_file, config.project_pods_root)

      # In case this spec is part of another pod's source, we need to dowload
      # the other pod's source.
      (part_of_specification || self).download_if_necessary!
    end

    def download_if_necessary!
      if pod_destroot.exist?
        puts "  * Skipping download of #{self}, pod already downloaded" unless config.silent?
      else
        puts "  * Downloading: #{self}" unless config.silent?
        download!
      end
    end

    # Downloads the source of the pod and places it in the project's pods
    # directory.
    #
    # Override this if you need to perform work before or after downloading the
    # pod, or if you need to implement custom dowloading. Eg:
    #
    #   Pod::Spec.new do
    #     def download!
    #       # pre-download
    #       super # or custom downloading
    #       # post-download
    #     end
    #   end
    def download!
      downloader = Downloader.for_source(pod_destroot, @source)
      downloader.download
      downloader.clean if config.clean
    end

  end

  Spec = Specification
end
