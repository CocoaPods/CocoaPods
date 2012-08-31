require 'xcodeproj/config'
require 'active_support/core_ext/string/strip.rb'

module Pod
  extend Config::Mixin

  def self._eval_podspec(path)
    string = File.open(path, 'r:utf-8')  { |f| f.read }
    # TODO: work around for Rubinius incomplete encoding in 1.9 mode
    string.encode!('UTF-8') if string.respond_to?(:encoding) && string.encoding.name != "UTF-8"
    eval(string, nil, path.to_s)
  end

  class Specification
    autoload :Set,        'cocoapods/specification/set'
    autoload :Statistics, 'cocoapods/specification/statistics'

    ### Initalization

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

    def initialize(parent = nil, name = nil)
      @parent, @name = parent, name
      @define_for_platforms = [:osx, :ios]
      @clean_paths, @subspecs = [], []
      @deployment_target = {}
      unless parent
        @source = {:git => ''}
      end

      # multi-platform attributes
      %w[ source_files
          public_header_files
          resources
          preserve_paths
          exclude_header_search_paths
          frameworks
          weak_frameworks
          libraries
          dependencies
          compiler_flags ].each do |attr|
        instance_variable_set( "@#{attr}", { :ios => [], :osx => [] } )
      end
      @xcconfig     = { :ios => Xcodeproj::Config.new, :osx => Xcodeproj::Config.new }
      @header_dir   = { :ios => nil, :osx => nil }
      @requires_arc = { :ios => nil, :osx => nil }
      @header_mappings_dir = { :ios => nil, :osx => nil }

      yield self if block_given?
    end

    ### Meta programming

    # Creates a top level attribute reader. A lambda can
    # be passed to process the ivar before returning it
    def self.top_attr_reader(attr, read_lambda = nil)
      define_method(attr) do
        ivar = instance_variable_get("@#{attr}")
        @parent ? top_level_parent.send(attr) : ( read_lambda ? read_lambda.call(self, ivar) : ivar )
      end
    end

    # Creates a top level attribute writer. A lambda can
    # be passed to initalize the value
    def self.top_attr_writer(attr, init_lambda = nil)
      define_method("#{attr}=") do |value|
        raise Informative, "#{self.inspect} Can't set `#{attr}' for subspecs." if @parent
        instance_variable_set("@#{attr}",  init_lambda ? init_lambda.call(value) : value);
      end
    end

    # Creates a top level attribute accessor. A lambda can
    # be passed to initialize the value in the attribute writer.
    def self.top_attr_accessor(attr, writer_labmda = nil)
      top_attr_reader attr
      top_attr_writer attr, writer_labmda
    end

    # Returns the value of the attribute for the active platform
    # chained with the upstream specifications. The ivar must store
    # the platform specific values as an array.
    #
    def self.pltf_chained_attr_reader(attr)
      define_method(attr) do
        active_plaform_check
        ivar_value = instance_variable_get("@#{attr}")[active_platform]
        @parent ? @parent.send(attr) + ivar_value : ( ivar_value )
      end
    end

    # Returns the first value defined of the attribute traversing the chain
    # upwards.
    #
    def self.pltf_first_defined_attr_reader(attr)
      define_method(attr) do
        active_plaform_check
        ivar_value = instance_variable_get("@#{attr}")[active_platform]
        ivar_value || (@parent.send(attr) if @parent)
      end
    end

    def active_plaform_check
      raise Informative, "#{self.inspect} not activated for a platform before consumption." unless active_platform
    end

    # Attribute writer that works in conjuction with the PlatformProxy.
    def self.platform_attr_writer(attr, block = nil)
      define_method("#{attr}=") do |value|
        current = instance_variable_get("@#{attr}")
        @define_for_platforms.each do |platform|
          block ?  current[platform] = block.call(value, current[platform]) : current[platform] = value
        end
      end
    end

    def self.pltf_chained_attr_accessor(attr, block = nil)
      pltf_chained_attr_reader(attr)
      platform_attr_writer(attr, block)
    end

    # The PlatformProxy works in conjuction with Specification#_on_platform.
    # It allows a syntax like `spec.ios.source_files = file`
    class PlatformProxy
      def initialize(specification, platform)
        @specification, @platform = specification, platform
      end

      %w{ source_files=
          public_header_files=
          resource=
          resources=
          preserve_paths=
          preserve_path=
          xcconfig=
          framework=
          frameworks=
          weak_framework=
          weak_frameworks=
          library=
          libraries=
          compiler_flags=
          deployment_target=
          header_dir=
          requires_arc
          dependency }.each do |method|
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

    ### Deprecated attributes - TODO: remove once master repo and fixtures have been updated

    attr_writer :part_of_dependency
    attr_writer :part_of

    top_attr_accessor :clean_paths, lambda { |patterns| pattern_list(patterns) }
    alias_method :clean_path=, :clean_paths=

    ### Regular attributes

    attr_accessor :parent
    attr_accessor :preferred_dependency

    def name
      @parent ? "#{@parent.name}/#{@name}" : @name
    end
    attr_writer :name

    # @return [String] The name of the pod.
    #
    def pod_name
      top_level_parent.name
    end

    ### Attributes that return the first value defined in the chain

    def platform
      @platform || ( @parent ? @parent.platform : nil )
    end

    def platform=(platform)
      @platform = Platform.new(*platform)
    end

    # If not platform is specified all the platforms are returned.
    def available_platforms
      platform.nil? ? @define_for_platforms.map { |platform| Platform.new(platform, deployment_target(platform)) } : [ platform ]
    end

    ### Top level attributes. These attributes represent the unique features of pod and can't be specified by subspecs.

    top_attr_accessor :defined_in_file
    top_attr_accessor :source
    top_attr_accessor :homepage
    top_attr_accessor :summary
    top_attr_accessor :documentation
    top_attr_accessor :version,             lambda { |v| Version.new(v) }

    top_attr_reader   :description,         lambda { |instance, ivar| ivar || instance.summary }
    top_attr_writer   :description,         lambda { |d| d.strip_heredoc }

    # @!method license
    #
    # @abstract
    #   The license of the pod.
    #
    # @example
    #   s.license = 'MIT'
    #   s.license = { :type => 'MIT', :file => 'license.txt', :text => 'Permission is granted to...' }
    #
    top_attr_accessor :license, lambda { |license|
      license = ( license.kind_of? String ) ? { :type => license } : license
      license[:text] = license[:text].strip_heredoc if license[:text]
      license
    }

    # @!method authors
    #
    # @abstract
    #   The list of the authors (with email) of the pod.
    #
    top_attr_accessor :authors, lambda { |*names_and_email_addresses|
      list = names_and_email_addresses.flatten
      unless list.first.is_a?(Hash)
        authors = list.last.is_a?(Hash) ? list.pop : {}
        list.each { |name| authors[name] = nil }
      end
      authors || list.first
    }

    alias_method :author=, :authors=

    ### Attributes **with** multiple platform support

    # @todo allow for subspecs?
    #
    top_attr_accessor :prefix_header_file,  lambda { |file| Pathname.new(file) }
    top_attr_accessor :prefix_header_contents

    pltf_chained_attr_accessor  :source_files,                lambda {|value, current| pattern_list(value) }
    pltf_chained_attr_accessor  :public_header_files,         lambda {|value, current| pattern_list(value) }
    pltf_chained_attr_accessor  :resources,                   lambda {|value, current| pattern_list(value) }
    pltf_chained_attr_accessor  :preserve_paths,              lambda {|value, current| pattern_list(value) } # Paths that should not be cleaned
    pltf_chained_attr_accessor  :exclude_header_search_paths, lambda {|value, current| pattern_list(value) } # Headers to be excluded from being added to search paths (RestKit)
    pltf_chained_attr_accessor  :frameworks,                  lambda {|value, current| (current << value).flatten }
    pltf_chained_attr_accessor  :weak_frameworks,             lambda {|value, current| (current << value).flatten }
    pltf_chained_attr_accessor  :libraries,                   lambda {|value, current| (current << value).flatten }

    alias_method :resource=,        :resources=
    alias_method :preserve_path=,   :preserve_paths=
    alias_method :framework=,       :frameworks=
    alias_method :weak_framework=,  :weak_frameworks=
    alias_method :library=,         :libraries=

    # @!method requires_arc=
    #
    # @abstract Wether the `-fobjc-arc' flag should be added to the compiler
    #   flags.
    #
    # @param [Bool] Wether the source files require ARC.
    #
    platform_attr_writer :requires_arc
    pltf_first_defined_attr_reader :requires_arc

    # @!method header_dir=
    #
    # @abstract The directory where to name space the headers files of
    #   the specification.
    #
    # @param [String] The headers directory.
    #
    platform_attr_writer           :header_dir, lambda { |dir, _| Pathname.new(dir) }
    pltf_first_defined_attr_reader :header_dir

    # If not provided the headers files are flattened
    #
    platform_attr_writer           :header_mappings_dir, lambda { |file, _| Pathname.new(file) }
    pltf_first_defined_attr_reader :header_mappings_dir

    # @!method xcconfig=
    #
    platform_attr_writer :xcconfig, lambda {|value, current| current.tap { |c| c.merge!(value) } }

    def xcconfig
      result = raw_xconfig.dup
      result.libraries.merge(libraries)
      result.frameworks.merge(frameworks)
      result.weak_frameworks.merge(weak_frameworks)
      result
    end

    def raw_xconfig
      @parent ? @parent.raw_xconfig.merge(@xcconfig[active_platform]) : @xcconfig[active_platform]
    end


    def compiler_flags
      if @parent
        flags = [@parent.compiler_flags]
      else
        flags = [requires_arc ? ' -fobjc-arc' : '']
      end
      (flags + @compiler_flags[active_platform].clone).join(' ')
    end

    platform_attr_writer :compiler_flags, lambda {|value, current| current << value }

    def dependency(*name_and_version_requirements)
      name, *version_requirements = name_and_version_requirements.flatten
      raise Informative, "A specification can't require self as a subspec" if name == self.name
      raise Informative, "A subspec can't require one of its parents specifications" if @parent && @parent.name.include?(name)
      dep = Dependency.new(name, *version_requirements)
      @define_for_platforms.each do |platform|
        @dependencies[platform] << dep
      end
      dep
    end

    # External dependencies are inherited by subspecs
    def external_dependencies(all_platforms = false)
      active_plaform_check unless all_platforms
      result = all_platforms ? @dependencies.values.flatten : @dependencies[active_platform]
      result += parent.external_dependencies if parent
      result
    end

    # A specification inherits the preferred_dependency or
    # all the compatible subspecs as dependencies
    def subspec_dependencies
      active_plaform_check
      specs = preferred_dependency ? [subspec_by_name("#{name}/#{preferred_dependency}")] : subspecs
      specs.compact \
        .select { |s| s.supports_platform?(active_platform) } \
        .map    { |s| Dependency.new(s.name, version) }
    end

    def dependencies
      external_dependencies + subspec_dependencies
    end

    include Config::Mixin

    def top_level_parent
      @parent ? @parent.top_level_parent : self
    end

    def subspec?
      !@parent.nil?
    end

    def subspec(name, &block)
      subspec = Specification.new(self, name, &block)
      @subspecs << subspec
      subspec
    end
    attr_reader :subspecs

    def recursive_subspecs
      @recursive_subspecs ||= begin
        mapper = lambda do |spec|
          spec.subspecs.map do |subspec|
            [subspec, *mapper.call(subspec)]
          end.flatten
        end
        mapper.call(self)
      end
    end

    def subspec_by_name(name)
      return self if name.nil? || name == self.name
      # Remove this spec's name from the beginning of the name we’re looking for
      # and take the first component from the remainder, which is the spec we need
      # to find now.
      remainder = name[self.name.size+1..-1]
      raise Informative, "Unable to find a specification named `#{name}' in `#{pod_name}'." unless remainder
      subspec_name = remainder.split('/').shift
      subspec = subspecs.find { |s| s.name == "#{self.name}/#{subspec_name}" }
      raise Informative, "Unable to find a specification named `#{name}' in `#{pod_name}'." unless subspec
      # If this was the last component in the name, then return the subspec,
      # otherwise we recursively keep calling subspec_by_name until we reach the
      # last one and return that
      remainder.empty? ? subspec : subspec.subspec_by_name(name)
    end

    def local?
      !source.nil? && !source[:local].nil?
    end

    def pod_destroot
      config.project_pods_root + top_level_parent.name
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
    # namespacing. However if the top level attribute accessor header_mappings_dir
    # is specified the namespacing will be preserved from that directory.
    def copy_header_mapping(from)
      header_mappings_dir ? from.relative_path_from(header_mappings_dir) : from.basename
    end

    # This is a convenience method which gets called after all pods have been
    # downloaded but before they have been installed, and the Xcode project and
    # related files have been generated. (It receives the Pod::LocalPod
    # instance generated form the specification and the #
    # Pod::Podfile::TargetDefinition instance for the current target.) Override
    # this to, for instance, to run any build script:
    #
    #   Pod::Spec.new do |s|
    #     def pre_install(pod, target_definition)
    #       Dir.chdir(pod.root){ `sh make.sh` }
    #     end
    #   end
    def pre_install(pod, target_definition)
    end

    # This is a convenience method which gets called after all pods have been
    # downloaded, installed, and the Xcode project and related files have been
    # generated. (It receives the Pod::Installer::TargetInstaller instance for
    # the current target.) Override this to, for instance, add to the prefix
    # header:
    #
    #   Pod::Spec.new do |s|
    #     def s.post_install(target_installer)
    #       prefix_header = config.project_pods_root + target_installer.prefix_header_filename
    #       prefix_header.open('a') do |file|
    #         file.puts(%{#ifdef __OBJC__\n#import "SSToolkitDefines.h"\n#endif})
    #       end
    #     end
    #   end
    def post_install(target_installer)
    end

    def podfile?
      false
    end

    # This is used by the specification set
    def dependency_by_top_level_spec_name(name)
      external_dependencies(true).each do |dep|
        return dep if dep.top_level_spec_name == name
      end
    end

    def to_s
      display_name = preferred_dependency.nil? ? name : "#{name}/#{preferred_dependency}"
      "#{display_name} (#{version})"
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

    # Returns whether the specification is supported in a given platform
    def supports_platform?(*platform)
      platform = platform[0].is_a?(Platform) ? platform[0] : Platform.new(*platform)
      available_platforms.any? { |p| platform.supports?(p) }
    end

    # Defines the active platform for comsumption of the specification and
    # returns self for method chainability.
    # The active platform must the the same accross the chain so attributes
    # that are inherited can be correctly resolved.
    def activate_platform(*platform)
      platform = platform[0].is_a?(Platform) ? platform[0] : Platform.new(*platform)
      raise Informative, "#{to_s} is not compatible with #{platform}." unless supports_platform?(platform)
      top_level_parent.active_platform = platform.to_sym
      self
    end

    top_attr_accessor :active_platform

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

    # @visibility private
    #
    # This is multi-platform and to support
    # subspecs with different platforms is is resolved as the
    # first non nil value accross the chain.
    def deployment_target=(version)
      raise Informative, "The deployment target must be defined per platform like `s.ios.deployment_target = '5.0'`." unless @define_for_platforms.count == 1
      @deployment_target[@define_for_platforms.first] = version
    end

    def deployment_target(platform)
      @deployment_target[platform] || ( @parent ? @parent.deployment_target(platform) : nil )
    end
  end
  Spec = Specification
end
