require 'pathname'

module Pod
  class Config
    def self.instance
      @instance ||= new
    end

    def self.instance=(instance)
      @instance = instance
    end

    attr_accessor :repos_dir, :project_root, :source_root, :project_pods_root, :rootspec, :clean, :verbose, :silent
    alias_method :clean?,   :clean
    alias_method :verbose?, :verbose
    alias_method :silent?,  :silent

    def initialize
      @repos_dir = Pathname.new(File.expand_path("~/.cocoapods"))
      @clean = true
      @verbose = false
      @silent = false
    end

    def project_root
      @project_root ||= Pathname.pwd
    end

    def source_root
      @source_root ||= project_root
    end

    def project_pods_root
      @project_pods_root ||= project_root + 'Pods'
    end

    def project_podfile
      unless @project_podfile
        @project_podfile = project_root + 'Podfile'
        unless @project_podfile.exist?
          @project_podfile = project_root.glob('*.podspec').first
        end
      end
      @project_podfile
    end

    def headers_symlink_root
      @headers_symlink_root ||= "#{project_pods_root}/Headers"
    end

    # Returns the spec at the pat returned from `project_podfile`.
    def rootspec
      unless @rootspec
        if project_podfile
          if project_podfile.basename.to_s == 'Podfile'
            @rootspec = Podfile.from_file(project_podfile)
          else
            @rootspec = Specification.from_file(project_podfile)
          end
        end
      end
      @rootspec
    end

    def ios?
      rootspec.platform == :ios if rootspec
    end

    def osx?
      rootspec.platform == :osx if rootspec
    end

    module Mixin
      def config
        Config.instance
      end
    end
  end
end
