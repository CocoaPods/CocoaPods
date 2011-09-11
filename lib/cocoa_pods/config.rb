require 'pathname'

module Pod
  class Config
    def self.instance
      @instance ||= new
    end

    def self.instance=(instance)
      @instance = instance
    end

    attr_accessor :repos_dir, :clean

    def initialize
      @repos_dir = Pathname.new(File.expand_path("~/.cocoa-pods"))
      @clean = true
    end

    def project_root
      Pathname.new(Dir.pwd)
    end

    def project_pods_root
      project_root + 'Pods'
    end

    module Mixin
      def config
        Config.instance
      end
    end
  end
end
