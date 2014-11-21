require 'rubygems'

module Pod
  # Provides support for the hook system of CocoaPods. The system is designed
  # especially for plugins. Interested clients can register to notifications by
  # name.
  #
  # The blocks, to prevent compatibility issues, will receive
  # one and only one argument: a context object. This object should be simple
  # storage of information (a typed hash). Notifications senders are
  # responsible to indicate the class of the object associated with their
  # notification name.
  #
  # Context object should not remove attribute accessors to not break
  # compatibility with the plugins (this promise will be honoured strictly
  # from CocoaPods 1.0).
  #
  module HooksManager
    # Represents a single registered hook.
    #
    class Hook
      # @return [String]
      #         The name of the hook's notification.
      #
      attr_reader :plugin_name

      # @return [String]
      #         The name of the plugin the hook came from.
      #
      attr_reader :name

      # @return [Proc]
      #         The block.
      #
      attr_reader :block

      # @param  [String] name        @see {#name}.
      #
      # @param  [String] plugin_name @see {#plugin_name}.
      #
      # @param  [Proc]   block       @see {#block}.
      #
      def initialize(name, plugin_name, block)
        raise ArgumentError, 'Missing name' unless name
        raise ArgumentError, 'Missing block' unless block

        UI.warn '[Hooks] The use of hooks without specifying a `plugin_name` ' \
                'has been deprecated.' unless plugin_name

        @name = name
        @plugin_name = plugin_name
        @block = block
      end
    end

    class << self
      # @return [Hash{Symbol => Array<Proc>}] The list of the blocks that are
      #         registered for each notification name.
      #
      attr_reader :registrations

      # Registers a block for the hook with the given name.
      #
      # @param  [Symbol] name
      #         The name of the notification.
      #
      # @param  [String] plugin_name
      #         The name of the plugin the hook comes from.
      #
      # @param  [Proc] block
      #         The block.
      #
      def register(name, plugin_name = nil, &block)
        @registrations ||= {}
        @registrations[name] ||= []
        @registrations[name] << Hook.new(name, plugin_name, block)
      end

      # Runs all the registered blocks for the hook with the given name.
      #
      # @param  [Symbol] name
      #         The name of the hook.
      #
      # @param  [Object] context
      #         The context object which should be passed to the blocks.
      #
      # @param  [Hash<String, Hash>] whitelisted_plugins
      #         The plugins that should be run, in the form of a hash keyed by
      #         plugin name, where the values are the custom options that should
      #         be passed to the hook's block if it supports taking a second
      #         argument.
      #
      def run(name, context, whitelisted_plugins = nil)
        raise ArgumentError, 'Missing name' unless name
        raise ArgumentError, 'Missing options' unless context

        if registrations
          hooks = registrations[name]
          if hooks
            UI.message "- Running #{name.to_s.gsub('_', ' ')} hooks" do
              hooks.each do |hook|
                next if whitelisted_plugins && !whitelisted_plugins.key?(hook.plugin_name)
                UI.message "- #{hook.plugin_name || 'unknown plugin'} from " \
                           "`#{hook.block.source_location.first}`" do
                  block = hook.block
                  if block.arity > 1
                    block.call(context, whitelisted_plugins[hook.plugin_name])
                  else
                    block.call(context)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
