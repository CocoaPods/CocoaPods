module Pod
  class Platform
    def self.ios
      new :ios
    end

    def self.osx
      new :osx
    end

    attr_reader :options, :deployment_target

    def initialize(symbolic_name, deployment_target = nil)
      @symbolic_name = symbolic_name
      if deployment_target
        version = deployment_target.is_a?(Hash) ? deployment_target[:deployment_target] : deployment_target # backwards compatibility from 0.6
        @deployment_target = Pod::Version.create(version)
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
        self == (other_platform_or_symbolic_name.name)
      end
    end

    def support?(other)
      return true if @symbolic_name.nil? || other.nil?
      @symbolic_name == other.name && (deployment_target.nil? || other.deployment_target.nil? || deployment_target >= other.deployment_target)
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
