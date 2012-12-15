module Pod

  # Stores the global configuration of CocoaPods.
  #
  class Config

    # The default settings for the configuration.
    #
    # Users can specify custom settings in `~/.cocoapods/config.yaml`.
    # An example of the contents of this file might look like:
    #
    #     ---
    #     skip_repo_update: true
    #     generate_docs: false
    #     doc_install: false
    #
    DEFAULTS = {
      :verbose             => false,
      :silent              => false,
      :skip_repo_update    => false,

      :clean               => true,
      :generate_docs       => true,
      :doc_install         => true,
      :integrate_targets   => true,
      :skip_repo_update    => true,
      :new_version_message => true,
    }

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

    # @return [Bool] Whether the downloader should use more aggressive caching
    #         options.
    #
    attr_accessor :agressive_cache
    alias_method  :agressive_cache?, :agressive_cache

    #--------------------------------------#

    # @!group Initialization

    def initialize
      configure_with(DEFAULTS)

      if user_settings_file.exist?
        require 'yaml'
        user_settings = YAML.load_file(user_settings_file)
        configure_with(user_settings)
      end
    end

    def verbose
      @verbose && !silent
    end

    #--------------------------------------#

    # @!group Paths

    # @return [Pathname] the directory where the CocoaPods sources are stored.
    #
    def repos_dir
      @repos_dir ||= Pathname.new(ENV['HOME'] + "/.cocoapods")
    end

    attr_writer :repos_dir

    # @return [Pathname] the root of the CocoaPods installation where the
    #         Podfile is located.
    #
    def project_root
      @project_root ||= Pathname.pwd
    end

    attr_writer :project_root

    # @return [Pathname] The root of the sandbox.
    #
    def project_pods_root
      @project_pods_root ||= @project_root + 'Pods'
    end

    attr_writer :project_pods_root

    # @return [Sandbox] The sandbox of the current project.
    #
    def sandbox
      @sandbox ||= Sandbox.new(project_pods_root)
    end

    # @return [Podfile] The Podfile to use for the current execution.
    #
    def podfile
      @podfile ||= begin
        Podfile.from_file(podfile_path) if podfile_path.exist?
      end
    end
    attr_writer :podfile

    # @return [Lockfile] The Lockfile to use for the current execution.
    #
    def lockfile
      @lockfile ||= begin
        Lockfile.from_file(lockfile_path) if lockfile_path.exist?
      end
    end

    #--------------------------------------#

    # @!group Helpers

    # private

    # @return [Pathname] The path of the file which contains the user settings.
    #
    def user_settings_file
      Pathname.new(ENV['HOME'] + "/.cocoapods/config.yaml")
    end

    # Sets the values of the attributes with the given hash.
    #
    # @param  [Hash{String,Symbol => Object}] values_by_key
    #         The values of the attributes grouped by key.
    #
    # @return [void]
    #
    def configure_with(values_by_key)
      values_by_key.each do |key, value|
        self.instance_variable_set("@#{key}", value)
      end
    end

    # Returns the path of the Podfile.
    #
    # @note The Podfile can be named either `CocoaPods.podfile` or `Podfile`.
    #       The first is preferred as it allows to specify an OS X UTI.
    #
    def podfile_path
      unless @podfile_path
        @podfile_path = project_root + 'CocoaPods.podfile'
        unless @podfile_path.exist?
          @podfile_path = project_root + 'Podfile'
        end
      end
      @podfile_path
    end

    # Returns the path of the Lockfile.
    #
    # @note The Lockfile is named `Podfile.lock`.
    #
    def lockfile_path
      @lockfile_path ||= project_root + 'Podfile.lock'
    end

    #--------------------------------------#

    # @return [Config] the current config instance creating one if needed.
    #
    def self.instance
      @instance ||= new
    end

    # Sets the current config instance. If set to nil the config will be
    # recreated when needed.
    #
    # @param  [Config, Nil] the instance.
    #
    # @return [void]
    #
    def self.instance=(instance)
      @instance = instance
    end

    #-------------------------------------------------------------------------#

    # Provides support for accessing the configuration instance in other
    # scopes.
    #
    module Mixin
      def config
        Config.instance
      end
    end
  end
end
