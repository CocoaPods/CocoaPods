module Pod
  class Podfile
    class Target
      attr_reader :name, :parent, :target_dependencies

      def initialize(name, parent = nil)
        @name, @parent, @target_dependencies = name, parent, []
      end

      def lib_name
        name == :default ? "libPods" : "libPods-#{name}"
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

    def initialize(&block)
      @targets = { :default => (@target = Target.new(:default)) }
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
    def dependency(name, *version_requirements)
      @target.target_dependencies << Dependency.new(name, *version_requirements)
    end

    def dependencies
      @targets.values.map(&:target_dependencies).flatten
    end

    # Specifies that a BridgeSupport metadata should be generated from the
    # headers of all installed Pods.
    #
    # This is for scripting languages such as MacRuby, Nu, and JSCocoa, which use
    # it to bridge types, functions, etc better.
    def generate_bridge_support!
      @generate_bridge_support = true
    end

    attr_reader :targets

    def target(name, options = {})
      @targets[name] = @target = Target.new(name, @target)
      yield
    ensure
      @target = @target.parent
    end

    # This is to be compatible with a Specification for use in the Installer and
    # Resolver.

    def podfile?
      true
    end

    attr_accessor :defined_in_file

    def generate_bridge_support?
      @generate_bridge_support
    end

    def dependency_by_name(name)
      dependencies.find { |d| d.name == name }
    end

    def validate!
      lines = []
      lines << "* the `platform` attribute should be either `:osx` or `:ios`" unless [:osx, :ios].include?(@platform)
      lines << "* no dependencies were specified, which is, well, kinda pointless" if dependencies.empty?
      raise(Informative, (["The Podfile at `#{@defined_in_file}' is invalid:"] + lines).join("\n")) unless lines.empty?
    end
  end
end
