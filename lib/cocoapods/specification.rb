require 'xcodeproj/config'

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
      spec = ::Pod._eval_podspec(path)
      spec.defined_in_file = path
      spec
    end

    attr_accessor :defined_in_file

    def initialize
      post_initialize
      yield self if block_given?
    end

    # TODO This is just to work around a MacRuby bug
    def post_initialize
      @dependencies, @source_files, @resources, @clean_paths, @subspecs = [], [], [], [], []
      @platform = Platform.new(nil)
      @xcconfig = Xcodeproj::Config.new
    end

    # Attributes

    attr_accessor :name
    attr_accessor :homepage
    attr_accessor :description
    attr_accessor :source
    attr_accessor :license

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
    end
    attr_reader :summary

    def description
      @description || summary
    end

    def part_of=(*name_and_version_requirements)
      self.part_of_dependency = *name_and_version_requirements
      @part_of.only_part_of_other_pod = true
    end
    attr_reader :part_of

    def part_of_dependency=(*name_and_version_requirements)
      @part_of = dependency(*name_and_version_requirements)
    end

    def source_files=(patterns)
      @source_files = pattern_list(patterns)
    end
    attr_reader :source_files

    def resources=(patterns)
      @resources = pattern_list(patterns)
    end
    attr_reader :resources
    alias_method :resource=, :resources=

    def clean_paths=(patterns)
      @clean_paths = pattern_list(patterns)
    end
    attr_reader :clean_paths
    alias_method :clean_path=, :clean_paths=

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
      flags << '-fobjc-arc' if requires_arc
      flags
    end

    def platform=(platform)
      @platform = Platform.new(platform)
    end
    attr_reader :platform

    attr_accessor :requires_arc

    def dependency(*name_and_version_requirements)
      name, *version_requirements = name_and_version_requirements.flatten
      dep = Dependency.new(name, *version_requirements)
      @dependencies << dep
      dep
    end
    attr_reader :dependencies

    def subspec(name, &block)
      subspec = Subspec.new(self, name, &block)
      @subspecs << subspec
      subspec
    end
    attr_reader :subspecs

    # Not attributes

    # TODO when we move to use a 'ResolveContext' this should happen there.
    attr_accessor :defined_in_set

    include Config::Mixin
    
    def local?
      !source.nil? && !source[:local].nil?
    end
    
    def local_path
      Pathname.new(File.expand_path(source[:local]))
    end

    def wrapper?
      source_files.empty? && !subspecs.empty?
    end

    def subspec_by_name(name)
      # Remove this spec's name from the beginning of the name we’re looking for
      # and take the first component from the remainder, which is the spec we need
      # to find now.
      remainder = name[self.name.size+1..-1].split('/')
      subspec_name = remainder.shift
      subspec = subspecs.find { |s| s.name == "#{self.name}/#{subspec_name}" }
      # If this was the last component in the name, then return the subspec,
      # otherwise we recursively keep calling subspec_by_name until we reach the
      # last one and return that
      remainder.empty? ? subspec : subspec.subspec_by_name(name)
    end

    def ==(other)
      object_id == other.object_id ||
        (self.class === other &&
          name && name == other.name &&
            version && version == other.version)
    end

    def dependency_by_top_level_spec_name(name)
      @dependencies.find { |d| d.top_level_spec_name == name }
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
      elsif local?
        local_path
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

    def pattern_list(patterns)
      if patterns.is_a?(Array) && (!defined?(Rake) || !patterns.is_a?(Rake::FileList))
        patterns
      else
        [patterns]
      end
    end

    # Returns all resource files of this pod, but relative to the
    # project pods root.
    def expanded_resources
      files = []
      resources.each do |pattern|
        pattern = pod_destroot + pattern
        pattern.glob.each do |file|
          files << file.relative_path_from(config.project_pods_root)
        end
      end
      files
    end

    # Returns all source files of this pod including header files,
    # but relative to the project pods root.
    #
    # If the pattern is the path to a directory, the pattern will
    # automatically glob for c, c++, Objective-C, and Objective-C++
    # files.
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
    def header_search_paths
      dirs = [header_dir] + copy_header_mappings.keys
      dirs.map { |dir| %{"$(PODS_ROOT)/Headers/#{dir}"} }
    end

    def to_s
      "#{name} (#{version})"
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
      missing << "`source_files'"               if source_files.empty? && subspecs.empty?
      # TODO
      # * validate subspecs

      incorrect = []
      allowed = [nil, :ios, :osx]
      incorrect << ["`platform'", allowed] unless allowed.include?(platform.name)

      no_errors_found = missing.empty? && incorrect.empty?

      unless no_errors_found
        message = "The following #{(missing + incorrect).size == 1 ? 'attribute is' : 'attributes are'}:\n"
        message << "* missing: #{missing.join(", ")}" unless missing.empty?
        message << "* incorrect: #{incorrect.map { |x| "#{x[0]} (#{x[1..-1]})" }.join(", ")}" unless incorrect.empty?
        raise Informative, message
      end

      no_errors_found
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

    class Subspec < Specification
      attr_reader :parent

      def initialize(parent, name)
        @parent, @name = parent, name
        # TODO a MacRuby bug, the correct super impl `initialize' is not called consistently
        #super(&block)
        post_initialize

        # A subspec is _always_ part of the source of its top level spec.
        self.part_of = top_level_parent.name, version
        # A subspec has a dependency on the parent if the parent is a subspec too.
        dependency(@parent.name, version) if @parent.is_a?(Subspec)

        yield self if block_given?
      end

      undef_method :name=, :version=, :source=, :defined_in_set=

      def top_level_parent
        top_level_parent = @parent
        top_level_parent = top_level_parent.parent while top_level_parent.is_a?(Subspec)
        top_level_parent
      end

      def name
        "#{@parent.name}/#{@name}"
      end

      # TODO manually forwarding the attributes that we have so far needed to forward,
      # but need to think if there's a better way to do this.

      def summary
        @summary ? @summary : top_level_parent.summary
      end

      # Override the getters to always return the value of the top level parent spec.
      [:version, :summary, :platform, :license, :authors, :requires_arc, :compiler_flags, :defined_in_set].each do |attr|
        define_method(attr) { top_level_parent.send(attr) }
      end

      def copy_header_mapping(from)
        top_level_parent.copy_header_mapping(from)
      end
    end

  end

  Spec = Specification
end
