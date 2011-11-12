module Pod
  class Podfile
    class TargetDefinition
      attr_reader :name, :parent, :target_dependencies

      def initialize(name, parent = nil)
        @name, @parent, @target_dependencies = name, parent, []
      end

      def lib_name
        name == :default ? "Pods" : "Pods-#{name}"
      end

      # Returns *all* dependencies of this target, not only the target specific
      # ones in `target_dependencies`.
      def dependencies
        @target_dependencies + (@parent ? @parent.dependencies : [])
      end
    end

    def self.from_file(path)
      podfile = Podfile.new do
        eval(path.read, nil, path.to_s)
      end
      podfile.defined_in_file = path
      podfile.validate!
      podfile
    end

    include Config::Mixin

    def initialize(&block)
      @target_definitions = { :default => (@target_definition = TargetDefinition.new(:default)) }
      instance_eval(&block)
    end

    # Specifies the platform for which a static library should be build.
    #
    # This can be either `:osx` for Mac OS X applications, or `:ios` for iOS
    # applications.
    def platform(platform = nil)
      platform ? @platform = platform : @platform
    end

    # Specifies a dependency of the project.
    #
    # A dependency requirement is defined by the name of the Pod and _optionally_
    # a list of version requirements.
    #
    #
    # When starting out with a project it is likely that you will want to use the
    # latest version of a Pod. If this is the case, simply omit the version
    # requirements.
    #
    #   dependency 'SSZipArchive'
    #
    #
    # Later on in the project you may want to freeze to a specific version of a
    # Pod, in which case you can specify that version number.
    #
    #   dependency 'Objection', '0.9'
    #
    #
    # Besides no version, or a specific one, it is also possible to use operators:
    #
    # * `> 0.1`    Any version higher than 0.1
    # * `>= 0.1`   Version 0.1 and any higher version
    # * `< 0.1`    Any version lower than 0.1
    # * `<= 0.1`   Version 0.1 and any lower version
    # * `~> 0.1.2` Version 0.1.2 and the versions upto 0.2, not including 0.2
    #
    #
    # Finally, a list of version requirements can be specified for even more fine
    # grained control.
    #
    # For more information, regarding versioning policy, see:
    #
    # * http://semver.org
    # * http://docs.rubygems.org/read/chapter/7
    #
    #
    # ## Dependency on a library, outside those available in a spec repo.
    #
    # ### From a podspec in the root of a library repo.
    #
    # Sometimes you may want to use the bleeding edge version of a Pod. Or a
    # specific revision. If this is the case, you can specify that with your
    # dependency declaration.
    #
    #
    # To use the `master` branch of the repo:
    #
    #   dependency 'TTTFormatterKit', :git => 'https://github.com/gowalla/AFNetworking.git'
    #
    #
    # Or specify a commit:
    #
    #   dependency 'TTTFormatterKit', :git => 'https://github.com/gowalla/AFNetworking.git', :commit => '082f8319af'
    #
    #
    # It is important to note, though, that this means that the version will
    # have to satisfy any other dependencies on the Pod by other Pods.
    #
    #
    # The `podspec` file is expected to be in the root of the repo, if this
    # library does not have a `podspec` file in its repo yet, you will have to
    # use one of the approaches outlined in the sections below.
    #
    #
    # ### From a podspec outside a spec repo, for a library without podspec.
    #
    # If a podspec is available from another source outside of the library’s
    # repo. Consider, for instance, a podpsec available via HTTP:
    #
    #   dependency 'JSONKit', :podspec => 'https://raw.github.com/gist/1346394/1d26570f68ca27377a27430c65841a0880395d72/JSONKit.podspec'
    #
    #
    # ### For a library without any available podspec
    #
    # Finally, if no man alive has created a podspec, for the library you want
    # to use, yet, you will have to specify the library yourself.
    #
    #
    # When you omit arguments and pass a block to `dependency`, an instance of
    # Pod::Specification is yielded to the block. This is the same class which
    # is normally used to specify a Pod.
    #
    #   dependency do |spec|
    #     spec.name         = 'JSONKit'
    #     spec.version      = '1.4'
    #     spec.source       = { :git => 'https://github.com/johnezang/JSONKit.git', :tag => 'v1.4' }
    #     spec.source_files = 'JSONKit.*'
    #   end
    #
    #
    # For more info on the definition of a Pod::Specification see:
    # https://github.com/CocoaPods/CocoaPods/wiki/A-pod-specification
    def dependency(*name_and_version_requirements, &block)
      @target_definition.target_dependencies << Dependency.new(*name_and_version_requirements, &block)
    end

    # Specifies that a BridgeSupport metadata should be generated from the
    # headers of all installed Pods.
    #
    # This is for scripting languages such as MacRuby, Nu, and JSCocoa, which use
    # it to bridge types, functions, etc better.
    def generate_bridge_support!
      @generate_bridge_support = true
    end

    # Defines a new static library target and scopes dependencies defined from
    # the given block. The target will by default include the dependencies
    # defined outside of the block, unless the `:exclusive => true` option is
    # given.
    #
    # Consider the following Podfile:
    #
    #   dependency 'ASIHTTPRequest'
    #
    #   target :debug do
    #     dependency 'SSZipArchive'
    #   end
    #
    #   target :test, :exclusive => true do
    #     dependency 'JSONKit'
    #   end
    #
    # This Podfile defines three targets. The first one is the `:default` target,
    # which produces the `libPods.a` file. The second and third are the `:debug`
    # and `:test` ones, which produce the `libPods-debug.a` and `libPods-test.a`
    # files.
    #
    # The `:default` target has only one dependency (ASIHTTPRequest), whereas the
    # `:debug` target has two (ASIHTTPRequest, SSZipArchive). The `:test` target,
    # however, is an exclusive target which means it will only have one
    # dependency (JSONKit).
    def target(name, options = {})
      parent = @target_definition
      @target_definitions[name] = @target_definition = TargetDefinition.new(name, options[:exclusive] ? nil : parent)
      yield
    ensure
      @target_definition = parent
    end

    # This hook allows you to make any last changes to the generated Xcode project
    # before it is written to disk, or any other tasks you might want to perform.
    #
    # For instance, say you'd want to customize the `OTHER_LDFLAGS` of all targets:
    #
    #   post_install do |installer|
    #     installer.project.targets.each do |target|
    #       target.buildConfigurations.each do |config|
    #         config.buildSettings['GCC_ENABLE_OBJC_GC'] = 'supported'
    #       end
    #     end
    #   end
    def post_install(&block)
      @post_install_callback = block
    end


    # Not attributes

    def podfile?
      true
    end

    attr_accessor :defined_in_file
    attr_reader :target_definitions

    def dependencies
      @target_definitions.values.map(&:target_dependencies).flatten
    end

    def dependency_by_name(name)
      dependencies.find { |d| d.name == name }
    end

    def generate_bridge_support?
      @generate_bridge_support
    end

    def post_install!(installer)
      @post_install_callback.call(installer) if @post_install_callback
    end

    def validate!
      lines = []
      lines << "* the `platform` attribute should be either `:osx` or `:ios`" unless [:osx, :ios].include?(@platform)
      lines << "* no dependencies were specified, which is, well, kinda pointless" if dependencies.empty?
      raise(Informative, (["The Podfile at `#{@defined_in_file}' is invalid:"] + lines).join("\n")) unless lines.empty?
    end
  end
end
