module Pod

  # Simple hook system for plugins.
  #
  # Plugins can register blocks for hooks with the given name.
  # The blocks, to prevent compatibility issues, will receive
  # one and only one argument: a hash which can include one or
  # more keys.
  #
  # The implicipt promise of the plugin system is not to remove
  # hooks and not remove keys from the options hash (honoured
  # strictly from version 1.0).
  #
  module Plugins
    class << self

      attr_reader :registrations

      # Registers a block for the hook with the given name.
      #
      # @param  [Symbol] name
      #         The name of the hook.
      #
      # @param  [Proc] block
      #         The block which should be registered for the
      #         hook.
      #
      # @return [void]
      #
      def register(name, &block)
        unless block
          raise ArgumentError, "Unable to register #{name} without being given a block"
        end
        @registrations ||= Hash.new
        @registrations[name] ||= Array.new
        @registrations[name] << block
      end

      # Runs all the registered blocks for a hook with the
      # given name.
      #
      # @param  [Symbol] name
      #         The name of the hook.
      #
      # @param  [Hash] options
      #         Any information that might be passed to the
      #         blocks.
      #
      # @return [void]
      #
      def run(name, options)
        if @registrations
          blocks = @registrations[name]
          if blocks
            blocks.each do |block|
              block.call(options)
            end
          end
        end
      end

      #-----------------------------------------------------------------------#

    end
  end
end
