module Pod
  class Config
    def self.instance
      @instance ||= new
    end

    def self.instance=(instance)
      @instance = instance
    end

    attr_accessor :repos_dir

    def initialize
      @repos_dir = File.expand_path("~/.cocoa-pods")
    end

    module Mixin
      def config
        Config.instance
      end
    end
  end
end
