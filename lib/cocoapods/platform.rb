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
      name.to_s
    end
    
    def to_sym
      name
    end
    
    def nil?
      name.nil?
    end
  end
end
