module Pod

  # A platform describes a build environment.
  # It captures information about the SDK and a deployment target.
  #
  # A platform represents all the known build environments if its name is nil.
  #
  class Platform

    # @return [Platform] Convenience method to initialize an iOS platform.
    #
    def self.ios
      new :ios
    end

    # @return [Platform] Convenience method to initialize an OS X platform.
    #
    def self.osx
      new :osx
    end

    # Constructs a platform from either another platform or by
    # specifying the symbolic name and optionally the deployment target.
    #
    # @overload initialize(platform)
    #   @param [Platform] platform Another platform or a symbolic name for the platform.
    #
    #   @example
    #
    #       p = Platform.new :ios
    #       Platform.new p
    #
    # @overload initialize(name, deployment_target)
    #   @param [Symbol] input Another platform or a symbolic name for the platform.
    #   @param [Version] deployment_target The optional deployment target if initialized by symbolic name.
    #
    #   @example
    #
    #       Platform.new(:ios)
    #       Platform.new(:ios, '4.3')
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

    # @return [Symbol] The name of the SDK represented by the platform.
    #
    def name
      @symbolic_name
    end

    # A deployment target can be initialized by any value that initializes a {Version}.
    #
    # @return [Version] The optional deployment target of the platform.
    #
    attr_reader :deployment_target

    def deployment_target= (version)
      @deployment_target = Pod::Version.create(version)
    end

    # @param [Platform, Symbol] other The other platform to check. If a symbol is
    #   passed the comparison does not take into account the deployment target.
    #
    # @return [Boolean] Whether two platforms are the equivalent.
    #
    def ==(other)
      if other.is_a?(Symbol)
        @symbolic_name == other
      else
        self.name == (other.name) && self.deployment_target == other.deployment_target
      end
    end

    # A platform supports (from the point of view of a pod) another platform if they represent the same SDK and if the
    # deployment target of the other is lower. If one of the platforms does not specify the deployment target, it is not taken into account.
    #
    # This method always returns true if one of platforms is nil.
    # @return Whether the platform supports being used in the environment described by another platform.
    #
    # @todo rename to supported_on?
    #
    def supports?(other)
      return true if @symbolic_name.nil? || other.nil?
      os_check      = @symbolic_name == other.name
      version_check = (deployment_target.nil? || other.deployment_target.nil? || deployment_target >= other.deployment_target)
      os_check && version_check
    end

    # @return [String] A string representation of the Platform including the deployment target if specified.
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

    # @return [Symbol] A Symbol representation of the SDK.
    #
    def to_sym
      name
    end

    # @return Whether the platform does not represents any SDK.
    #
    # A platform behaves as nil if doesn't specify an SDK and implicitly represents all the available platforms.
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
