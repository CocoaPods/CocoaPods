module Pod

  # Stores the global configuration of CocoaPods.
  #
  class Config

  autoload :ConfigManager, 'cocoapods/config/config_manager'

    # The default settings for the configuration.
    #
    # Users can specify custom settings in `~/.cocoapods/config.yaml`.
    # An example of the contents of this file might look like:
    #
    #     ---
    #     skip_repo_update: true
    #     new_version_message: false
    #
    DEFAULTS = {
      :verbose             => false,
      :silent              => false,
      :skip_repo_update    => false,

      :clean               => true,
      :integrate_targets   => true,
      :new_version_message => true,

      :cache_root          => Pathname.new(File.join(ENV['HOME'], 'Library/Caches/CocoaPods')),
      :max_cache_size      => 500,
      :aggressive_cache    => false,
    }

    public

    #-------------------------------------------------------------------------#

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

    # @return [Bool] Whether a message should be printed when a new version of
    #         CocoaPods is available.
    #
    attr_accessor :new_version_message
    alias_method  :new_version_message?, :new_version_message

    #-------------------------------------------------------------------------#

    # @!group Installation

    # @return [Bool] Whether the installer should clean after the installation.
    #
    attr_accessor :clean
    alias_method  :clean?, :clean

    # @return [Bool] Whether CocoaPods should integrate a user target and build
    #         the workspace or just create the Pods project.
    #
    attr_accessor :integrate_targets
    alias_method  :integrate_targets?, :integrate_targets


    # @return [Bool] Whether the installer should skip the repos update.
    #
    attr_accessor :skip_repo_update
    alias_method  :skip_repo_update?, :skip_repo_update

    public

    #-------------------------------------------------------------------------#

    # @!group Cache

    # @return [Fixnum] The maximum size for the cache expressed in Mb.
    #
    attr_accessor :max_cache_size

    # @return [Pathname] The directory where CocoaPods should cache remote data
    #         and other expensive to compute information.
    #
    attr_accessor :cache_root

    def cache_root
      @cache_root.mkpath unless @cache_root.exist?
      @cache_root
    end

    # Allows to set whether the downloader should use more aggressive caching
    # options.
    #
    # @note The aggressive cache has lead to issues if a tag is updated to
    #       point to another commit.
    #
    attr_writer :aggressive_cache

    # @return [Bool] Whether the downloader should use more aggressive caching
    #         options.
    #
    def aggressive_cache?
      @aggressive_cache || (ENV['CP_AGGRESSIVE_CACHE'] == 'TRUE')
    end

    # def aggressive_cache?
    #   @aggressive_cache? || (parent.aggressive_cache? if parent)
    # end

    # pod config verbose true --global
    # pod config verbose true
    # pod config unset verbose
    # pod config get verbose
    #
    # pod config  # defaults to show
    #
    # ~/.cocoapods/config.yaml
    # ~/code/OSS/AwesomeApp/Pods/config.yaml
    # 
    # load the configuration file (path is returned by the manager)
    # convert to hash
    # user_config? BOOL
    # keypath STRING
    # value STRING



    # manager = Config::ConfigManager.new
  
    # manager.set_local(keypath, value)
    # manager.unset_local(keypath)

    # manager.set_global(keypath, value)
    # manager.unset_global(keypath)


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

    LOCAL_OVERRIDES = 'PER_PROJECT_REPO_OVERRIDES'
    GLOBAL_OVERRIDES = 'GLOBAL_REPO_OVERRIDES'

    def store_global(pod_name, pod_path)
      config_hash[GLOBAL_OVERRIDES] ||= {}
      config_hash[GLOBAL_OVERRIDES][pod_name] = pod_path
    end

    def store_local(pod_name, pod_path)
      config_hash[LOCAL_OVERRIDES] ||= {}
      config_hash[LOCAL_OVERRIDES][project_name] ||= {}
      config_hash[LOCAL_OVERRIDES][project_name][pod_name] = pod_path
    end

    def delete_local(pod_name)
      config_hash[LOCAL_OVERRIDES] ||= {}
      config_hash[LOCAL_OVERRIDES][project_name].delete(pod_name)
    end

    def delete_global(pod_name)
      config_hash[GLOBAL_OVERRIDES] ||= {}
      config_hash[GLOBAL_OVERRIDES].delete(pod_name)
    end

    def config_hash
      @config_hash ||= load_config
    end

    def load_config
      FileUtils.touch(user_settings_file) unless File.exists? user_settings_file
      YAML.load(File.open(user_settings_file)) || {}
    end

    def project_name
      `basename #{Dir.pwd}`.chomp
    end

    def write_config_to_file
      File.open(user_settings_file, 'w') { |f| f.write(config_hash.delete_blank.to_yaml) }
    end

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
