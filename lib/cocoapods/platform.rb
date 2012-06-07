module Pod

  # Describes an build envronment. It caputures information about the SDK and a deployment target.
  #
  class Platform

    # @return [Platform] Convenience method to initialize an iOS platform
    #
    def self.ios
      new :ios
    end

    # @return [Platform] Convenience method to initialize an OS X platform
    #
    def self.osx
      new :osx
    end

    # Constructs a platform from either another platform or by
    # specifying the symbolic name and optionally the deployment target.
    #
    # @param [Platform, Symbol] input Another platform or a symbolic name for the platform.
    # @param [Version, {Symbol=>Object}] deployment_target The optional deployment target if initalized by symbolic name
    #
    # Examples:
    #
    # ```
    # Platform.new(:ios)
    # Platform.new(:ios, '4.3')
    # Platform.new(Platform.new(:ios))
    # ```
    #
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

    # @return [Symbol] The name of the SDK reppresented by the platform.
    #
    def name
      @symbolic_name
    end

    # The optional deployment target of the platform.
    # A deployment target can be specified as a string.
    #
    # @return [Version]
    attr_reader :deployment_target

    def deployment_target= (version)
      @deployment_target = Pod::Version.create(version)
    end

    # Checks if two platforms are the equivalent.
    #
    # @param [Platform, Symbol] other The other platform to check. If a symbol is
    #                                 passed the comparison does not take into
    #                                 account the deployment target.
    #
    # @return [Boolean]
    #
    def ==(other)
      if other.is_a?(Symbol)
        @symbolic_name == other
      else
        self.name == (other.name) && self.deployment_target == other.deployment_target
      end
    end

    # A platfrom supports (from the point of view of a pod) another platform if they reppresent the same SDK and if the
    # deployment target of the other is lower. If one of the platforms does not specify the deployment target, it is not taken into account.
    #
    # This method always returns true if one of platforms is nil.
    #
    # **TODO**: rename to supported_on?
    def supports?(other)
      return true if @symbolic_name.nil? || other.nil?
      os_check      = @symbolic_name == other.name
      version_check = (deployment_target.nil? || other.deployment_target.nil? || deployment_target >= other.deployment_target)
      os_check && version_check
    end

    # A string reppresentation of the Platform including the deployment target if specified.
    #
    # @return [String] A string reppresentation.
    #
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

    # @return [Symbol] A Symbol reppresentation of the SDK.
    #
    def to_sym
      name
    end

    # A platform behaves as nil if doesn't specify an SDK.
    # A nil platform reppresents all the available platforms.
    #
    def nil?
      name.nil?
    end

    # @return Whether the platform requires legacy architectures for iOS.
    #
    def requires_legacy_ios_archs?
      return unless deployment_target
      (name == :ios) && (deployment_target < Pod::Version.new("4.3"))
    end
  end
end
