module Pod

  class Config

    require 'yaml'

    # The config manager is responsible for reading and writing the config.yaml
    # file. 
    # 
    class ConfigManager

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

    class NoKeyError < ArgumentError; end


    def get_setting(keypath)
      value = global_config[keypath] || get_environment(keypath) || DEFAULTS[keypath.to_sym]
      if value.nil?
        raise NoKeyError, "Unrecognized keypath for configuration `#{keypath}`. " \
        "\nSupported ones are:\n - #{DEFAULTS.keys.join("\n - ")}"
      end
      value
    end

    def set_global(keypath, value)
      hash = load_configuration
      if value == 'true'
        value = true
      end

      hash[keypath] = value
      store_configuration(hash)
    end

    def unset_global(keypath)

    end

    private

    def global_config
      @global_config ||= load_configuration
    end

      # @return [Hash]
      #
      def load_configuration
        if global_config_filepath.exist?
          YAML.load_file(global_config_filepath)
        else
          Hash.new
        end
      end

      def store_configuration(hash)
        yaml = YAML.dump(hash)
        global_config_filepath
        File.open(global_config_filepath, 'w') { |f| f.write(yaml) }
      end

      
      # @return [Pathname] The path of the file which contains the user settings.
      #
      def global_config_filepath
        home_dir + "config.yaml"
      end

      def local_config_filepath

      end

      # @return [Pathname] the directory where repos, templates and configuration
      #         files are stored.
      #
      def home_dir
        # TODO: test ENV
        # @home_dir ||= Pathname.new(ENV['CP_HOME_DIR'] || "~/.cocoapods").expand_path
        @home_dir ||= Pathname.new("~/.cocoapods").expand_path
      end

      def get_environment(keypath)
        value = ENV["CP_#{keypath.upcase}"]
        if value == 'TRUE'
          true
        else
          false
        end
      end

    end

  end

end
