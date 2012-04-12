module Pod
  class Platform
    attr_reader :options

    def initialize(symbolic_name, options = {})
      @symbolic_name = symbolic_name
      @options = options
    end

    def name
      @symbolic_name
    end

    def ==(other_platform_or_symbolic_name)
      if other_platform_or_symbolic_name.is_a?(Symbol)
        @symbolic_name == other_platform_or_symbolic_name
      else
        self == (other_platform_or_symbolic_name.name)
      end
    end

    def to_s
      case @symbolic_name
      when :ios
        'iOS'
      when :osx
        'OS X'
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

    def deployment_target
      if (opt = options[:deployment_target])
        Pod::Version.new(opt)
      end
    end

    def requires_legacy_ios_archs?
      return unless deployment_target
      (name == :ios) && (deployment_target < Pod::Version.new("4.3"))
    end
  end
end
