module Pod

  # A platform describes an SDK name and deployment target. If no name
  # is provided an instance of this class behaves like nil and represents
  # all the known platforms
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
    # @overload initialize(name, opts)
    #   @deprecated Remove after adding a warning to {Podfile} class.
    #   @param [Symbol] name The name of platform.
    #   @param [Hash] opts The options to create a platform with.
    #   @option opts [String, Version] :deployment_target The deployment target.
    #
    # @overload initialize(platform)
    #   @param [Platform] platform Another {Platform}.
    #
    #   @example
    #
    #       platform = Platform.new(:ios)
    #       Platform.new(platform)
    #
    def initialize(input = nil, target = nil)
      if input.is_a? Platform
        @symbolic_name = input.name
        @deployment_target = input.deployment_target
        @declared_deployment_target = input.declared_deployment_target
      else
        @symbolic_name = input

        target = target[:deployment_target] if target.is_a?(Hash)
        @declared_deployment_target = target

        unless target
          case @symbolic_name
          when :ios
            target = '4.3'
          when :osx
            target = '10.6'
          else
            target = ''
          end
        end
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

    # @return [Version] The deployment target declared on initialization.
    #
    attr_reader :declared_deployment_target

    # @todo Deprecate
    #
    def deployment_target= (version)
      @deployment_target = Pod::Version.create(version)
    end

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

    # A platform supports (from the point of view of a pod) another platform
    # if they represent the same SDK and if the deployment target of the other
    # is lower. If one of the platforms does not specify the deployment target,
    # it is not taken into account.
    #
    # @note This method returns true if one of the platforms is nil.
    #
    # @return Whether the platform supports being used in the environment
    #   described by another platform.
    #
    # @todo rename to supported_on?
    #
    def supports?(other)
      return true if @symbolic_name.nil? || other.nil?
      other = Platform.new(other)
      (name == other.name) && (deployment_target >= other.deployment_target)
    end

    # @return [String] A string representation including the deployment target.
    #
    def to_s
      case @symbolic_name
      when :ios
        s = 'iOS'
      when :osx
        s = 'OS X'
      else
        s = 'iOS - OS X'
      end
      s << " #{declared_deployment_target}" if declared_deployment_target
      s
    end

    # @return [Symbol] A Symbol representation of the name.
    #
    def to_sym
      name
    end

    # @return Whether the platform does not represents any SDK.
    #
    # @note A platform behaves as nil if doesn't specify an name and
    # represents all the known platforms.
    #
    def nil?
      name.nil?
    end

    # @return Whether the platform requires legacy architectures for iOS.
    #
    def requires_legacy_ios_archs?
      (name == :ios) && (deployment_target < Version.new("4.3"))
    end
  end
end
