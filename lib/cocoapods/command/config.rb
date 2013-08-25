module Pod
  class Command

    # This command was made in first place for supporting local repos.
    # Command uses file ~/.config/cocoapods
    #
    # Sample usage:
    #   pod config --local ObjectiveSugar ~/code/OSS/ObjectiveSugar
    #   pod config --global ObjectiveRecord ~/code/OSS/ObjectiveRecord
    #
    #   pod config --delete --local ObjectiveSugar
    #   pod config --delete --global ObjectiveSugar
    #
    # For both storing and deleting, --local is default and it can be ommitted
    #   pod config Kiwi ~/code/OSS/Kiwi
    #   pod config --delete Kiwi
    #
    class Config < Command
      CONFIG_FILE_PATH = File.expand_path('~/.config/cocoapods')
      LOCAL_OVERRIDES = 'PER_PROJECT_REPO_OVERRIDES'
      GLOBAL_OVERRIDES = 'GLOBAL_REPO_OVERRIDES'

      self.summary = 'Something like `bundle config` ... but better.'
      self.description = <<-DESC
        Use `pod config` when you're developing a pod that uses another pod of yours.
        This way you will reference it locally without modifying a Podfile.
      DESC

      self.arguments = '[pod name] [--local, --global, --delete] [path]'

      def initialize(argv)
        @global = argv.flag?('global')
        @local = argv.flag?('local') || !@global
        @should_delete = argv.flag?('delete')
        @pod_name   = argv.shift_argument
        @pod_path   = argv.shift_argument
        super
      end

      def self.options
        [['--local' , 'Uses the local pod for the current project only'],
         ['--global', 'Uses the local pod everywhere'],
         ['--delete', 'Removes the local pod from configuration']]
      end

      def run
        help! unless args_are_valid?
        update_config
      end


      private

      def args_are_valid?
        valid = !!@pod_name
        valid &= !!@pod_path unless @should_delete
        valid
      end

      def update_config
        if @should_delete
          @local ? delete_local_config : delete_global_config
        else
          @local ? store_local_config : store_global_config
        end
        write_config_to_file
      end

      def store_global_config
        config_hash[GLOBAL_OVERRIDES][@pod_name] = @pod_path
      end

      def store_local_config
        config_hash[LOCAL_OVERRIDES][project_name] ||= {}
        config_hash[LOCAL_OVERRIDES][project_name][@pod_name] = @pod_path
      end

      def delete_local_config
        config_hash[LOCAL_OVERRIDES][project_name].delete(@pod_name)
      end

      def delete_global_config 
        config_hash[GLOBAL_OVERRIDES].delete(@pod_name)
      end

      def config_hash
        @config_hash ||= load_config
      end

      def load_config
        FileUtils.touch(CONFIG_FILE_PATH) unless File.exists? CONFIG_FILE_PATH
        config = YAML.load(File.open(CONFIG_FILE_PATH)) || {}
        config[LOCAL_OVERRIDES] ||= {}
        config[GLOBAL_OVERRIDES] ||= {}
        config
      end

      def project_name
        `basename #{Dir.pwd}`.chomp
      end

      def write_config_to_file
        File.open(CONFIG_FILE_PATH, 'w') { |f| f.write(config_hash.delete_blank.to_yaml) }
      end

    end
  end
end

class Hash
  def delete_blank
    delete_if{|k, v| v.empty? or v.instance_of?(Hash) && v.delete_blank.empty?}
  end
end

