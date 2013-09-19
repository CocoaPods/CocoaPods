module Pod

  # Stores the global configuration of CocoaPods.
  #
  class Config

  autoload :ConfigManager, 'cocoapods/config/config_manager'

    public

    #-------------------------------------------------------------------------#

    # @!group Initialization

    # Sets the values of the attributes with the given hash.
    #
    # @param  [Hash{String,Symbol => Object}] values_by_key
    #         The values of the attributes grouped by key.
    #
    # @return [void]
    #

    def initialize(settings = {})
      settings.each do |key, value|
        self.instance_variable_set("@#{key}", value)
      end
    end

    def verbose
      @verbose && !silent
    end

    public

    #-------------------------------------------------------------------------#

    # @!group Paths

    # @return [Pathname] the directory where the CocoaPods sources are stored.
    #
    def repos_dir
      @repos_dir ||= Pathname.new(ENV['CP_REPOS_DIR'] || "~/.cocoapods/repos").expand_path
    end

    attr_writer :repos_dir

    # @return [Pathname] the directory where the CocoaPods templates are stored.
    #
    def templates_dir
      @templates_dir ||= Pathname.new(ENV['CP_TEMPLATES_DIR'] || "~/.cocoapods/templates").expand_path
    end

    # @return [Pathname] the root of the CocoaPods installation where the
    #         Podfile is located.
    #
    def installation_root
      current_path = Pathname.pwd
      unless @installation_root
        while(!current_path.root?)
          if podfile_path_in_dir(current_path)
            @installation_root = current_path
            unless current_path == Pathname.pwd
              UI.puts("[in #{current_path}]")
            end
            break
          else
            current_path = current_path.parent
          end
        end
        @installation_root ||= Pathname.pwd
      end
      @installation_root
    end

    attr_writer :installation_root
    alias :project_root :installation_root

    # @return [Pathname] The root of the sandbox.
    #
    def sandbox_root
      @sandbox_root ||= installation_root + 'Pods'
    end

    attr_writer :sandbox_root
    alias :project_pods_root :sandbox_root

    # @return [Sandbox] The sandbox of the current project.
    #
    def sandbox
      @sandbox ||= Sandbox.new(sandbox_root)
    end

    # @return [Podfile] The Podfile to use for the current execution.
    # @return [Nil] If no Podfile is available.
    #
    def podfile
      @podfile ||= Podfile.from_file(podfile_path) if podfile_path
    end
    attr_writer :podfile

    # @return [Lockfile] The Lockfile to use for the current execution.
    # @return [Nil] If no Lockfile is available.
    #
    def lockfile
      @lockfile ||= Lockfile.from_file(lockfile_path) if lockfile_path
    end

    # Returns the path of the Podfile.
    #
    # @note The Podfile can be named either `CocoaPods.podfile.yaml`,
    #       `CocoaPods.podfile` or `Podfile`.  The first two are preferred as
    #       they allow to specify an OS X UTI.
    #
    # @return [Pathname]
    # @return [Nil]
    #
    def podfile_path
      @podfile_path ||= podfile_path_in_dir(installation_root)
    end

    # Returns the path of the Lockfile.
    #
    # @note The Lockfile is named `Podfile.lock`.
    #
    def lockfile_path
      @lockfile_path ||= installation_root + 'Podfile.lock'
    end

    # Returns the path of the default Podfile pods.
    #
    # @note The file is expected to be named Podfile.default
    #
    # @return [Pathname]
    #
    def default_podfile_path
      @default_podfile_path ||= templates_dir + "Podfile.default"
    end

    # Returns the path of the default Podfile test pods.
    #
    # @note The file is expected to be named Podfile.test
    #
    # @return [Pathname]
    #
    def default_test_podfile_path
      @default_test_podfile_path ||= templates_dir + "Podfile.test"
    end

    # @return [Pathname] The file to use a cache of the statistics provider.
    #
    def statistics_cache_file
      cache_root + 'statistics.yml'
    end

   # @return [Pathname] The file to use to cache the search data.
    #
    def search_index_file
      cache_root + 'search_index.yaml'
    end

    public

    #-------------------------------------------------------------------------#

    # @!group Dependency Injection

    # @return [Downloader] The downloader to use for the retrieving remote
    #         source.
    #
    def downloader(target_path, options)
      downloader = Downloader.for_target(target_path, options)
      downloader.cache_root = cache_root
      downloader.max_cache_size = max_cache_size
      downloader.aggressive_cache = aggressive_cache?
      downloader
    end

    # @return [Specification::Set::Statistics] The statistic provider to use
    #         for specifications.
    #
    def spec_statistics_provider
      Specification::Set::Statistics.new(statistics_cache_file)
    end

    private

    #-------------------------------------------------------------------------#

    # @!group Private helpers

    # @return [Array<String>] The filenames that the Podfile can have ordered
    #         by priority.
    #
    PODFILE_NAMES = [
      'CocoaPods.podfile.yaml',
      'CocoaPods.podfile',
      'Podfile',
    ]

    # Returns the path of the Podfile in the given dir if any exists.
    #
    # @param  [Pathname] dir
    #         The directory where to look for the Podfile.
    #
    # @return [Pathname] The path of the Podfile.
    # @return [Nil] If not Podfile was found in the given dir
    #
    def podfile_path_in_dir(dir)
      PODFILE_NAMES.each do |filename|
        candidate = dir + filename
        if candidate.exist?
          return candidate
        end
      end
      nil
    end


    public

    #-------------------------------------------------------------------------#

    # @!group Local repos
    #
    #

    public

    #-------------------------------------------------------------------------#

    # @!group Singleton

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

class Hash
  def delete_blank
    delete_if { |k, v| v.empty? or v.instance_of?(Hash) && v.delete_blank.empty? }
  end
end
