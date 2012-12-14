require 'pathname'

module Pod

  # Stores the global configuration of CocoaPods.
  #
  class Config

    # @!group Paths

    # @return [Pathname] the directory where the CocoaPods sources are stored.
    #
    attr_accessor :repos_dir

    # @return [Pathname] the root of the CocoaPods installation where the
    #         Podfile is located.
    #
    attr_accessor :project_root

    # @return [Pathname] The root of the sandbox.
    #
    # @todo   Why is this needed? Can't clients use config.sandbox.root?
    #
    attr_accessor :project_pods_root

    #--------------------------------------#

    # @!group UI

    # @return [Bool] Whether CocoaPods should provide detailed output about the
    #         performed actions.
    #
    attr_accessor :verbose
    alias_method  :verbose?, :verbose

    # @return [Bool] Whether CocoaPods should produce not output.
    #
    attr_accessor :silent
    alias_method  :silent?, :silent

    # @return [Bool] Whether the generated documentation should be installed to
    #         Xcode.
    #
    attr_accessor :new_version_message
    alias_method  :new_version_message?, :new_version_message

    #--------------------------------------#

    # @!group Installation

    # @return [Bool] Whether the installer should clean after the installation.
    #
    attr_accessor :clean
    alias_method  :clean?, :clean

    # @return [Bool] Whether the documentation should be generated for the
    #         installed Pods.
    #
    attr_accessor :generate_docs
    alias_method  :generate_docs?, :generate_docs

    # @return [Bool] Whether the generated documentation should be installed to
    #         Xcode.
    #
    attr_accessor :doc_install
    alias_method  :doc_install?, :doc_install

    # @return [Bool] Whether CocoaPods should integrate a user target and build
    #         the workspace or just create the Pods project.
    #
    attr_accessor :integrate_targets
    alias_method  :integrate_targets?, :integrate_targets


    # @return [Bool] Whether the installer should skip the repos update.
    #
    attr_accessor :skip_repo_update
    alias_method  :skip_repo_update?, :skip_repo_update

    # @return [Bool] Whether the donwloader should use more agressive caching
    #         options.
    #
    attr_accessor :agressive_cache
    alias_method  :agressive_cache?, :agressive_cache

    #--------------------------------------#

    def initialize
      @repos_dir = Pathname.new(File.expand_path("~/.cocoapods"))
      @verbose = @silent = @skip_repo_update = false
      @clean = @generate_docs = @doc_install = @integrate_targets = @new_version_message = true
    end

    # @return [Pathname] the root of the CocoaPods instance where the Podfile
    #         is located.
    #
    # @todo   Move to initialization.
    #
    def project_root
      @project_root ||= Pathname.pwd
    end

    # @return [Pathname] The root of the sandbox.
    #
    # @todo   Why is this needed? Can't clients use config.sandbox.root?
    #
    def project_pods_root
      @project_pods_root ||= project_root + 'Pods'
    end

    # @return [Podfile] The Podfile to use for the current execution.
    #
    def podfile
      @podfile ||= begin
        Podfile.from_file(project_podfile) if project_podfile.exist?
      end
    end
    attr_writer :podfile

    # @return [Lockfile] The Lockfile to use for the current execution.
    #
    def lockfile
      @lockfile ||= begin
        Lockfile.from_file(project_lockfile) if project_lockfile.exist?
      end
    end

    # @return [Sandbox] The sandbox of the current project.
    #
    def sandbox
      @sandbox ||= Sandbox.new(project_pods_root)
    end

    #--------------------------------------#

    # @!group Helpers

    # Returns the path of the Podfile.
    #
    # @note The Podfile can be named either `CocoaPods.podfile` or `Podfile`.
    #       The first is preferred as it allows to specify an OS X UTI.
    #
    # @todo Rename to podfile_path.
    #
    def project_podfile
      unless @project_podfile
        @project_podfile = project_root + 'CocoaPods.podfile'
        unless @project_podfile.exist?
          @project_podfile = project_root + 'Podfile'
        end
      end
      @project_podfile
    end

    # Returns the path of the Lockfile.
    #
    # @note The Lockfile is named `Podfile.lock`.
    #
    # @todo Rename to lockfile_path.
    #
    def project_lockfile
      @project_lockfile ||= project_root + 'Podfile.lock'
    end

    # @todo this should be controlled by the sandbox
    #
    def headers_symlink_root
      @headers_symlink_root ||= "#{project_pods_root}/Headers"
    end

    #--------------------------------------#

    def self.instance
      @instance ||= new
    end

    def self.instance=(instance)
      @instance = instance
    end

    #-------------------------------------------------------------------------#

    # Provides support for using the configuration instance in other scopes.
    #
    module Mixin
      def config
        Config.instance
      end
    end
  end
end
