require 'pathname'

module Pod
  class Config
    def self.instance
      @instance ||= new
    end

    def self.instance=(instance)
      @instance = instance
    end

    attr_accessor :repos_dir, :project_root, :project_pods_root
    attr_accessor :clean, :verbose, :silent
    attr_accessor :generate_docs, :doc_install
    attr_accessor :integrate_targets
    attr_accessor :git_cache_size

    alias_method :clean?,             :clean
    alias_method :verbose?,           :verbose
    alias_method :silent?,            :silent
    alias_method :generate_docs?,     :generate_docs
    alias_method :doc_install?,       :doc_install
    alias_method :integrate_targets?, :integrate_targets

    def initialize
      @repos_dir = Pathname.new(File.expand_path("~/.cocoapods"))
      @verbose = @silent = false
      @clean = @generate_docs = @doc_install = @integrate_targets = true
    end

    def project_root
      @project_root ||= Pathname.pwd
    end

    def project_pods_root
      @project_pods_root ||= project_root + 'Pods'
    end

    def project_podfile
      @project_podfile ||= project_root + 'Podfile'
    end

    def headers_symlink_root
      @headers_symlink_root ||= "#{project_pods_root}/Headers"
    end

    # Returns the spec at the pat returned from `project_podfile`.
    def podfile
      @podfile ||= begin
        Podfile.from_file(project_podfile) if project_podfile.exist?
      end
    end
    attr_writer :podfile

    def ios?
      # TODO: deprecate in 0.7
      podfile.target_definitions[:default].platform == :ios if podfile
    end

    def osx?
      # TODO: deprecate in 0.7
      podfile.target_definitions[:default].platform == :osx if podfile
    end

    module Mixin
      def config
        Config.instance
      end
    end
  end
end
