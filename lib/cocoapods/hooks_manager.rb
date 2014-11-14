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
      # @param  [Proc] block
      #         The block.
      #
      def register(name, &block)
        raise ArgumentError, 'Missing name' unless name
        raise ArgumentError, 'Missing block' unless block

        @registrations ||= {}
        @registrations[name] ||= []
        @registrations[name] << block
      end

      # Runs all the registered blocks for the hook with the given name.
      #
      # @param  [Symbol] name
      #         The name of the hook.
      #
      # @param  [Object] context
      #         The context object which should be passed to the blocks.
      #
      def run(name, context)
        raise ArgumentError, 'Missing name' unless name
        raise ArgumentError, 'Missing options' unless context

        if @registrations
          blocks = @registrations[name]
          if blocks
            pretty_name = name.to_s.gsub('_', ' ')
            UI.message "- Running #{pretty_name} hooks" do
              blocks.each do |block|
                gem_name_lambda = lambda do
                  file, _line = block.source_location
                  gem_spec = Gem::Specification.find do |spec|
                    spec.require_paths.find { |f| file.include? File.join(spec.full_gem_path, f) }
                  end
                  gem_name = (gem_spec && gem_spec.name) || File.basename(file, '.rb')
                end

                UI.message "- #{gem_name_lambda.call}" do
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
