module Pod

  # A platform describes an SDK name and deployment target.
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
    # @overload initialize(name, deployment_target)
    #   @param [Symbol] name The name of platform.
    #   @param [String, Version] deployment_target The optional deployment.
    #     If not provided a default value according to the platform name will
    #     be assigned.
    #
    #   @note that if the name is not specified a default deployment
    #     target will not be assigned.
    #
    #   @example
    #
    #       Platform.new(:ios)
    #       Platform.new(:ios, '4.3')
    #
    # @overload initialize(platform)
    #   @param [Platform] platform Another {Platform}.
    #
    #   @example
    #
    #       platform = Platform.new(:ios)
    #       Platform.new(platform)
    #
    def initialize(input, target = nil)
      if input.is_a? Platform
        @symbolic_name = input.name
        @deployment_target = input.deployment_target
      else
        @symbolic_name = input
        target = target[:deployment_target] if target.is_a?(Hash)
        @deployment_target = Version.create(target)
      end
    end

    # @return [Symbol] The name of the SDK represented by the platform.
    #
    def name
      @symbolic_name
    end

    # @return [Version] The deployment target of the platform.
    #
    attr_reader :deployment_target

    # @param [Platform, Symbol] other The other platform to check.
    #
    # @note If a symbol is passed the comparison does not take into account
    # the deployment target.
    #
    # @return [Boolean] Whether two platforms are the equivalent.
    #
    def ==(other)
      if other.is_a?(Symbol)
        @symbolic_name == other
      else
        (name == other.name) && (deployment_target == other.deployment_target)
      end
    end

    # In the context of operating system SDKs, a platform supports another
    # one if they have the same name and the other platform has a minor or
    # equal deployment target.
    #
    # @return Whether the platform supports another platform.
    #
    def supports?(other)
      other = Platform.new(other)
      if other.deployment_target && deployment_target
      (other.name == name) && (other.deployment_target <= deployment_target)
      else
        other.name == name
      end
    end

    # @return [String] A string representation including the deployment target.
    #
    def to_s
      case @symbolic_name
      when :ios
        s = 'iOS'
      when :osx
        s = 'OS X'
      end
      s << " #{deployment_target}" if deployment_target
      s
    end

    # @return [Symbol] A Symbol representation of the name.
    #
    def to_sym
      name
    end

    # @return Whether the platform requires legacy architectures for iOS.
    #
    def requires_legacy_ios_archs?
      (name == :ios) && deployment_target && (deployment_target < Version.new("4.3"))
    end
  end
end
