module Pod
  class Sandbox
    attr_reader :root
    
    def initialize(path)
      @root = path
      FileUtils.mkdir_p(@root)
    end
    
    def implode
      @root.rmtree
    end
  end
end
