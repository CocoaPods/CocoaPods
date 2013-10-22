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

      include Pod::Config

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
        #help! unless args_are_valid?
        #update_config
      end


      private

      def args_are_valid?
        valid = !!@pod_name
        valid &= !!@pod_path unless @should_delete
        valid
      end

      def update_config
        if @should_delete
          @local ? config.delete_local(@pod_name) : config.delete_global(@pod_name)
        else
          @local ? config.store_local(@pod_name, @pod_path) : config.store_global(@pod_name, @pod_path)
        end
        config.write_config_to_file
      end

    end
  end
end

