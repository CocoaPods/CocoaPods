module Pod
  class Platform
    def self.ios
      new :ios
    end

    def self.osx
      new :osx
    end

    attr_reader :deployment_target

    ##
    # Public: Constructs a platform from either another platform or by
    # specifying the symbolic name and optionally the deployment target.
    #
    # input             - Another platform or the symbolic name of the platform.
    # deployment_target - The optional deployment target if initalized by
    #                     symbolic name
    #
    # Examples
    #
    #   Platform.new(:ios)
    #   Platform.new(:ios, '4.3')
    #   Platform.new(Platform.new(:ios))
    #
    # Returns nothing.

    def initialize(input = nil, deployment_target = nil)
      if input.is_a? Platform
        @symbolic_name = input.name
        @deployment_target = input.deployment_target
      else
        @symbolic_name = input
        if deployment_target
          version = deployment_target.is_a?(Hash) ? deployment_target[:deployment_target] : deployment_target # backwards compatibility from 0.6
          @deployment_target = Pod::Version.create(version)
        end
      end
    end

    def name
      @symbolic_name
    end

    def deployment_target= (version)
      @deployment_target = Pod::Version.create(version)
    end

    def ==(other_platform_or_symbolic_name)
      if other_platform_or_symbolic_name.is_a?(Symbol)
        @symbolic_name == other_platform_or_symbolic_name
      else
        self.name == (other_platform_or_symbolic_name.name) && self.deployment_target == other_platform_or_symbolic_name.deployment_target
      end
    end

    def supports?(other)
      return true if @symbolic_name.nil? || other.nil?
      os_check      = @symbolic_name == other.name
      version_check = (deployment_target.nil? || other.deployment_target.nil? || deployment_target >= other.deployment_target)
      os_check && version_check
    end

    def to_s
      case @symbolic_name
      when :ios
        'iOS' + (deployment_target ? " #{deployment_target}" : '')
      when :osx
        'OS X' + (deployment_target ? " #{deployment_target}" : '')
      else
        'iOS - OS X'
      end
    end

    def to_sym
      name
    end

    def nil?
      name.nil?
    end

    def requires_legacy_ios_archs?
      return unless deployment_target
      (name == :ios) && (deployment_target < Pod::Version.new("4.3"))
    end
  end
end
