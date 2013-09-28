module Pod

  # Contains the configuration manager and environment modules.
  # Also provides dependency injection for downloader and
  # statistics provider
  #
  # This module is not intented to be included - you probably
  # want to include Config::Manager and/or Config::Enironment
  #
  module Config

    autoload :ConfigManager, 'cocoapods/config/config_manager'
    autoload :ConfigEnvironment, 'cocoapods/config/environment'


    # Provides support for accessing the configuration manager
    # instance in other scopes.
    #
    module Manager
      def config
        ConfigManager.instance
      end
    end

    # Provides support for accessing the environment instance in other
    # scopes.
    #
    module Environment
      def environment
        ConfigEnvironment.instance
      end
    end

    public

    extend Environment
    extend Manager
    #-------------------------------------------------------------------------#

    # @!group Dependency Injection

    # @return [Downloader] The downloader to use for the retrieving remote
    #         source.
    #
    def self.downloader(target_path, options)
      downloader = Downloader.for_target(target_path, options)
      downloader.cache_root = environment.cache_root
      downloader.max_cache_size = config.max_cache_size
      downloader.aggressive_cache = config.aggressive_cache?
      downloader
    end

    # @return [Specification::Set::Statistics] The statistic provider to use
    #         for specifications.
    #
    def self.spec_statistics_provider
      Specification::Set::Statistics.new(environment.statistics_cache_file)
    end

  end
end

