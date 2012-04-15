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
    attr_accessor :doc, :doc_install, :force_doc
    attr_accessor :integrate_targets

    alias_method :clean?,             :clean
    alias_method :verbose?,           :verbose
    alias_method :silent?,            :silent
    alias_method :doc?,               :doc # TODO rename to generate_docs?
    alias_method :doc_install?,       :doc_install
    alias_method :force_doc?,         :force_doc
    alias_method :integrate_targets?, :integrate_targets

    def initialize
      @repos_dir = Pathname.new(File.expand_path("~/.cocoapods"))
      @verbose = @silent = @force_doc = false
      @clean = @doc = @doc_install = @integrate_targets = true
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

    def ios?
      require 'colored'
      caller.find { |line| line =~ /^(.+.podspec):\d*/ }
      puts "[!] The use of `config.ios?` is deprecated and will be removed in version 0.7.#{" Called from: #{$1}" if $1}".red
      podfile.target_definitions[:default].platform == :ios if podfile
    end

    def osx?
      require 'colored'
      caller.find { |line| line =~ /^(.+.podspec):\d*/ }
      puts "[!] The use of `config.osx?` is deprecated and will be removed in version 0.7.#{" Called from: #{$1}" if $1}".red
      podfile.target_definitions[:default].platform == :osx if podfile
    end

    module Mixin
      def config
        Config.instance
      end
    end
  end
end
