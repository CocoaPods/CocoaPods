module Pod
  class LocalPod
    attr_reader :specification
    
    def initialize(specification, sandbox)
      @specification, @sandbox = specification, sandbox
    end
    
    def root
      @sandbox.root + specification.name
    end
    
    def create
      root.mkpath unless root.exist?
    end
    
    def chdir(&block)
      create
      Dir.chdir(root, &block)
    end
    
    def implode
      root.rmtree if root.exist?
    end
  end
end
