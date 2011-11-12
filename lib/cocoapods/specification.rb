module Pod
  extend Config::Mixin

  def self._eval_podspec(path)
    eval(path.read, nil, path.to_s)
  end

  class Specification
    autoload :Set, 'cocoapods/specification/set'

    # The file is expected to define and return a Pods::Specification.
    def self.from_file(path)
      unless path.exist?
        raise Informative, "No podspec exists at path `#{path}'."
      end
      spec = Pod._eval_podspec(path)
      spec.defined_in_file = path
      spec
    end

    attr_accessor :defined_in_file

    def initialize
      @dependencies = []
      @xcconfig = Xcodeproj::Config.new
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
      @source_files = patterns.flatten
    end
    attr_reader :source_files

    def resources=(*patterns)
      @resources = patterns.flatten
    end
    attr_reader :resources
    alias_method :resource=, :resources=

    def clean_paths=(*patterns)
      @clean_paths = patterns.flatten.map { |p| Pathname.new(p) }
    end
    attr_reader :clean_paths

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
      self.xcconfig = { 'OTHER_LDFLAGS' => libraries.join(' -l').strip }
    end
    alias_method :library=, :libraries=

    def header_dir=(dir)
      @header_dir = Pathname.new(dir)
    end
    def header_dir
      @header_dir || pod_destroot_name
    end

    attr_writer :compiler_flags
    def compiler_flags
      flags = "#{@compiler_flags} "
      flags << '-fobj-arc' if @requires_arc
      flags
    end

    # These are attributes which are also on a Podfile

    attr_accessor :platform

    attr_accessor :requires_arc

    attr_accessor :generate_bridge_support
    alias_method :generate_bridge_support?, :generate_bridge_support

    def dependency(*name_and_version_requirements)
      name, *version_requirements = name_and_version_requirements.flatten
      dep = Dependency.new(name, *version_requirements)
      @dependencies << dep
      dep
    end
    attr_reader :dependencies

    # Not attributes

    include Config::Mixin

    def ==(other)
      self.class === other &&
        name && name == other.name &&
          version && version == other.version
    end

    def dependency_by_name(name)
      @dependencies.find { |d| d.name == name }
    end

    def part_of_specification_set
      if part_of
        Set.by_specification_name(part_of.name)
      end
    end

    # Returns the specification for the pod that this pod's source is a part of.
    def part_of_specification
      (set = part_of_specification_set) && set.specification
    end

    def pod_destroot
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
      !part_of.nil?
    end

    def podfile?
      false
    end

    # Returns all resource files of this pod, but relative to the
    # project pods root.
    def expanded_resources
      files = []
      [*resources].each do |pattern|
        pattern = pod_destroot + pattern
        pattern = pattern + '*' if pattern.directory?
        pattern.glob.each do |file|
          files << file.relative_path_from(config.project_pods_root)
        end
      end
      files
    end

    # Returns all source files of this pod including header files,
    # but relative to the project pods root.
    def expanded_source_files
      files = []
      [*source_files].each do |pattern|
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
      "`#{name}' version `#{version}'"
    end

    def inspect
      "#<#{self.class.name} for #{to_s}>"
    end

    def validate!
      missing = []
      missing << "`name'"                       unless name
      missing << "`version'"                    unless version
      missing << "`summary'"                    unless summary
      missing << "`homepage'"                   unless homepage
      missing << "`author(s)'"                  unless authors
      missing << "either `source' or `part_of'" unless source || part_of
      missing << "`source_files'"               unless source_files

      incorrect = []
      allowed = [nil, :ios, :osx]
      incorrect << ["`platform'", allowed] unless allowed.include?(platform)

      unless missing.empty? && incorrect.empty?
        message = "The following #{(missing + incorrect).size == 1 ? 'attribute is' : 'attributes are'}:\n"
        message << "* missing: #{missing.join(", ")}" unless missing.empty?
        message << "* incorrect: #{incorrect.map { |x| "#{x[0]} (#{x[1..-1]})" }.join(", ")}" unless incorrect.empty?
        raise Informative, message
      end
    end

    # Install and download hooks

    # Places the activated specification in the project's pods directory.
    #
    # Override this if you need to perform work before or after activating the
    # pod. Eg:
    #
    #   Pod::Spec.new do |s|
    #     def s.install!
    #       # pre-install
    #       super
    #       # post-install
    #     end
    #   end
    def install!
      puts "==> Installing: #{self}" unless config.silent?
      if defined_in_file && !(config.project_pods_root + defined_in_file.basename).exist?
        config.project_pods_root.mkpath
        FileUtils.cp(defined_in_file, config.project_pods_root)
      end

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
    #   Pod::Spec.new do |s|
    #     def s.download!
    #       # pre-download
    #       super # or custom downloading
    #       # post-download
    #     end
    #   end
    def download!
      downloader = Downloader.for_source(pod_destroot, source)
      downloader.download
      downloader.clean(clean_paths) if config.clean
    end

    # This is a convenience method which gets called after all pods have been
    # downloaded, installed, and the Xcode project and related files have been
    # generated. (It receives the Pod::Installer::Target instance for the current
    # target.) Override this to, for instance, add to the prefix header:
    #
    #   Pod::Spec.new do |s|
    #     def s.post_install(target)
    #       prefix_header = config.project_pods_root + target.prefix_header_filename
    #       prefix_header.open('a') do |file|
    #         file.puts(%{#ifdef __OBJC__\n#import "SSToolkitDefines.h"\n#endif})
    #       end
    #     end
    #   end
    def post_install(target)
    end

  end

  Spec = Specification
end
