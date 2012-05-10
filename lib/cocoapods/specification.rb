require 'xcodeproj/config'
require 'colored'

module Pod
  extend Config::Mixin

  def self._eval_podspec(path)
    eval(path.read, nil, path.to_s)
  end

  class Specification
    autoload :Set,        'cocoapods/specification/set'
    autoload :Statistics, 'cocoapods/specification/statistics'

    # The file is expected to define and return a Pods::Specification.
    # If name is equals to nil it returns the top level Specification,
    # otherwise it returned the specification with the name that matches
    def self.from_file(path, subspec_name = nil)
      unless path.exist?
        raise Informative, "No podspec exists at path `#{path}'."
      end
      spec = ::Pod._eval_podspec(path)
      spec.defined_in_file = path
      spec.subspec_by_name(subspec_name)
    end

    attr_accessor :parent

    def initialize(parent = nil, name = nil)
      @parent, @name = parent, name if parent
      post_initialize
      yield self if block_given?
    end

    # TODO This is just to work around a MacRuby bug
    def post_initialize
      @define_for_platforms = [:osx, :ios]
      @clean_paths, @subspecs = [], []
      @deployment_target = {}
      initialized_multiplatform_attributes

      # deprecated attributes
      @source = {:git => ''}
    end

    # Deprecated attributes
    # TODO: remove once master repo and fixtures are updated
    def part_of_dependency=(value)
      puts "[!] `part_of_dependency' is deprecated in #{name}".cyan
    end

    def part_of=(value)
      puts "[!] `part_of' is deprecated in #{name}".cyan
    end

    # Normal attributes

    def name
      @parent ? "#{@parent.name}/#{@name}" : @name
    end

    attr_writer :name

    def summary
      @summary || ( @parent.summary if @parent )
    end

    attr_writer :summary

    #TODO: relocate

    def platform
      @platform || ( @parent ? @parent.platform : Platform.new(nil) )
    end

    def platform=(platform)
      @platform = Platform.new(*platform)
    end

    def available_platforms
      platform.nil? ?  @define_for_platforms.map { |platform| Platform.new(platform, @deployment_target[platform]) } : [ platform ]
    end

    attr_writer :main_subspec

    def main_subspec
      return self unless @main_subspec
      subspecs.find { |s| s.name == "#{self.name}/#{@main_subspec}" }
    end

    ### Top level attributes. These attributes represent the unique features of pod and can't be specified by subspecs.

    # Attributes **without** multiple platform support

    # Creates a top level attribute reader.
    def self.top_attr_reader(attr, read_lambda = nil)
      define_method(attr) do
        ivar = instance_variable_get("@#{attr}")
        @parent ? top_level_parent.send(attr) : ( read_lambda ? read_lambda.call(self, ivar) : ivar )
      end
    end

    # Creates a top level attribute writer. A lambda can be passed to initialize the value.
    def self.top_attr_writer(attr, init_lambda = nil)
      raise Informative "Can't set #{attr} for subspecs" if @parent
      define_method("#{attr}=") do |value|
        instance_variable_set("@#{attr}",  init_lambda ? init_lambda.call(value) : value);
      end
    end

    # Creates a top level attribute accessor. A lambda can be passed to initialize the value in the attribute writer.
    def self.top_attr_accessor(attr, writer_labmda = nil)
      top_attr_reader attr
      top_attr_writer attr, writer_labmda
    end



    top_attr_accessor :defined_in_file
    top_attr_accessor :homepage
    top_attr_accessor :source
    top_attr_accessor :documentation
    top_attr_accessor :requires_arc
    top_attr_accessor :license,     lambda { |l| ( l.kind_of? String ) ? { :type => l } : l }
    top_attr_accessor :version,     lambda { |v| Version.new(v) }
    top_attr_accessor :readme_file, lambda { |file| Pathname.new(file) }
    top_attr_accessor :authors,     lambda { |a| parse_authors(a) }
    alias_method      :author=, :authors=

    top_attr_reader   :description, lambda { |instance, ivar| ivar || instance.summary }
    top_attr_writer   :description

    #TODO: are those top level?
    top_attr_accessor :prefix_header_contents
    top_attr_accessor :prefix_header_file, lambda { |file| Pathname.new(file) }
    top_attr_reader   :header_dir,  lambda {|instance, ivar| ivar || instance.pod_destroot_name }
    top_attr_writer   :header_dir,  lambda {|dir| Pathname.new(dir) }

    #TODO: deprecate and clean all unused files
    top_attr_accessor :clean_paths, lambda { |patterns| pattern_list(patterns) }
    alias_method      :clean_path=, :clean_paths=

    def self.parse_authors(*names_and_email_addresses)
      list = names_and_email_addresses.flatten
      unless list.first.is_a?(Hash)
        authors = list.last.is_a?(Hash) ? list.pop : {}
        list.each { |name| authors[name] = nil }
      end
      authors || list.first
    end

    ### Attributes **with** multiple platform support

    class PlatformProxy
      def initialize(specification, platform)
        @specification, @platform = specification, platform
      end

      %w{ source_files= resource= resources= xcconfig= framework= frameworks= library= libraries= compiler_flags= deployment_target= dependency }.each do |method|
        define_method(method) do |args|
          @specification._on_platform(@platform) do
            @specification.send(method, args)
          end
        end
      end
    end

    def ios
      PlatformProxy.new(self, :ios)
    end

    def osx
      PlatformProxy.new(self, :osx)
    end

    # It returns the value of the attribute for the current platform. In this way clients do not need to be aware of wich
    # attributes are multiplatform
    def self.platform_attr_reader(attr)
      define_method(attr) do
        raise Informative, "#{self.inspect}##{attr} not activated for a platform before consumption." unless active_platform
        instance_variable_get("@#{attr}")[active_platform]
      end
    end

    # It returns the value of a pod merged with upstream. The optional lambda can specify how to merge the values
    def self.pltf_chained_attr_reader(attr, merge_lambda = nil)
      # TODO: chain the value with the upstream
      define_method(attr) do
        raise Informative, "#{self.inspect}##{attr} not activated for a platform before consumption." unless active_platform
        instance_variable_get("@#{attr}")[active_platform]
      end
    end

    def self.platform_attr_writer(attr, block = nil)
      define_method("#{attr}=") do |value|
        current = instance_variable_get("@#{attr}")
        @define_for_platforms.each do |platform|
            block ?  current[platform] = block.call(value, current[platform]) : current[platform] = value
        end
      end
    end

    def initialized_multiplatform_attributes
      %w[ source_files resources frameworks libraries dependencies compiler_flags].each do |attr|
        instance_variable_set( "@#{attr}", { :ios => [], :osx => [] } )
      end
      @dependencies = { :ios => [], :osx => [] }
      @xcconfig = { :ios => Xcodeproj::Config.new, :osx => Xcodeproj::Config.new }
    end

    pltf_chained_attr_reader  :source_files
    platform_attr_writer      :source_files,
                              lambda {|value, current| pattern_list(value) }

    pltf_chained_attr_reader  :resources
    platform_attr_writer      :resources,
                              lambda {|value, current| pattern_list(value) }
    alias_method              :resource=, :resources=

    # frameworks are chained by the xcofing attr_reader
    platform_attr_reader      :frameworks
    platform_attr_writer      :frameworks,
                              lambda {|value, current| current << value }
    alias_method              :framework=, :frameworks=

    # libraries are chained by the xcofing attr_reader
    platform_attr_reader      :libraries
    platform_attr_writer      :libraries,
                              lambda {|value, current| current << value }
    alias_method              :library=, :libraries=

    def xcconfig
      if @parent
        chained = @parent.xcconfig.dup.merge! @xcconfig[active_platform]
      else
        chained = @xcconfig[active_platform].dup
      end
      chained.merge!({ 'OTHER_LDFLAGS' =>  '-l' << libraries.join(' -l').strip }) unless libraries.empty?
      chained.merge!({ 'OTHER_LDFLAGS' =>  '-framework ' << frameworks.join(' -framework ').strip }) unless frameworks.empty?
      chained
    end

    platform_attr_writer :xcconfig, lambda {|value, current| current.tap { |c| c.merge!(value) } }

    def compiler_flags
      if @parent
        chained = @compiler_flags[active_platform].dup.unshift @parent.compiler_flags[active_platform]
      else
        chained = @compiler_flags[active_platform].dup
        chained.unshift '-fobjc-arc' if @requires_arc
        chained.unshift ''
      end
      chained.join(' ')
    end

    platform_attr_writer :compiler_flags, lambda {|value, current| current << value }

    def dependency(*name_and_version_requirements)
      name, *version_requirements = name_and_version_requirements.flatten
      dep = Dependency.new(name, *version_requirements)
      @define_for_platforms.each do |platform|
        @dependencies[platform] << dep
      end
      dep
    end

    def dependencies
      raise Informative, "#{self.inspect}#dependencies not activated for a platform before consumption." unless active_platform
      @dependencies[active_platform] + subspecs.map { |s| Dependency.new(s.name, version) }
    end

    # TODO: make top level?
    def deployment_target=(version)
      raise Informative, "The deployment target must be defined per platform like s.ios.deployment_target = '5.0'" unless @define_for_platforms.count == 1
      @deployment_target[@define_for_platforms.first] = version
    end

    ### Not attributes

    # @visibility private
    #
    # This is used by PlatformProxy to assign attributes for the scoped platform.
    def _on_platform(platform)
      before, @define_for_platforms = @define_for_platforms, [platform]
      yield
    ensure
      @define_for_platforms = before
    end

    include Config::Mixin

    def top_level_parent
      @parent ? @parent.top_level_parent : self
    end

    def subspec(name, &block)
      subspec = Specification.new(self, name, &block)
      @subspecs << subspec
      subspec
    end
    attr_reader :subspecs

    def recursive_subspecs
      unless @recursive_subspecs
        mapper = lambda do |spec|
            spec.subspecs.map do |subspec|
              [subspec, *mapper.call(subspec)]
            end.flatten
          end
          @recursive_subspecs = mapper.call self
      end
      @recursive_subspecs
    end

    def subspec_by_name(name)
      return main_subspec if name.nil? || name == self.name
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

    # Returns if the specification is supported in a given platform
    def supports_platform?(plaform)
      available_platforms.any? { |p| platform.supports? p }
    end

    # Defines the active platform for comsumption of the specification and returns self
    def activate_platform(platform)
      platform = Platform.new(platform) if platform.is_a? Hash
      raise "[!] #{name} does not support platform".red unless supports_platform?(platform)
      top_level_parent.active_platform = platform.to_sym
      self
    end

    # The active platform needs to be the same accross the chain
    top_attr_accessor :active_platform

    def local?
      !source.nil? && !source[:local].nil?
    end

    def local_path
      Pathname.new(File.expand_path(source[:local]))
    end

    def pod_destroot
      if local?
        local_path
      else
        config.project_pods_root + top_level_parent.name
      end
    end

    def pod_destroot_name
      if root = pod_destroot
        root.basename
      end
    end

    def self.pattern_list(patterns)
      if patterns.is_a?(Array) && (!defined?(Rake) || !patterns.is_a?(Rake::FileList))
        patterns
      else
        [patterns]
      end
    end

    # This method takes a header path and returns the location it should have
    # in the pod's header dir.
    #
    # By default all headers are copied to the pod's header dir without any
    # namespacing. You can, however, override this method in the podspec, or
    # copy_header_mappings for full control.
    def copy_header_mapping(from)
      @parent ? top_level_parent.copy_header_mapping(from) : from.basename
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

    def podfile?
      false
    end

    def dependency_by_top_level_spec_name(name)
      @dependencies.each do |_, platform_deps|
        platform_deps.each do |dep|
          return dep if dep.top_level_spec_name == name
        end
      end
    end

    def to_s
      "#{name} (#{version})"
    end

    def inspect
      "#<#{self.class.name} for #{to_s}>"
    end

    def ==(other)
      object_id == other.object_id ||
        (self.class === other &&
         name && name == other.name &&
         version && version == other.version)
    end
  end
  Spec = Specification
end
