require 'active_support/hash_with_indifferent_access'

module Pod
  class Installer
    class InstallationOptions
      def self.from_podfile(podfile)
        name, options = podfile.installation_method
        unless name.downcase == 'cocoapods'
          raise Informative "Currently need to specify a `cocoapods` install, you chose `#{name}`."
        end
        new(options)
      end

      # Defines a new installation option.
      #
      # @param  [#to_s] name the name of the option.
      #
      # @param  default the default value for the option.
      #
      # @param [Boolean] boolean whether the option has a boolean value.
      #
      # @return [void]
      #
      # @!macro [attach] option
      #
      #   @note this option defaults to $2.
      #
      #   @return the $1 $0 for installation.
      #
      def self.option(name, default, boolean: true)
        name = name.to_s
        raise ArgumentError, "The `#{name}` option is already defined" if defaults.key?(name)
        defaults[name] = default
        attr_accessor name
        alias_method "#{name}?", name if boolean
      end

      def self.defaults
        @defaults ||= {}
      end

      def self.all_options
        defaults.keys
      end

      def initialize(options)
        options = ActiveSupport::HashWithIndifferentAccess.new(options)
        unknown_keys = options.keys - self.class.all_options.map(&:to_s)
        raise Informative, "Unknown installation options: #{unknown_keys.to_sentence}" unless unknown_keys.empty?
        self.class.defaults.each do |key, default|
          value = options.fetch(key, default)
          send("#{key}=", value)
        end
      end

      option :clean, true
      option :deduplicate_targets, true
      option :deterministic_uuids, true
      option :integrate_targets, true
      option :lock_pod_sources, true

      module Mixin
        def Mixin.included(mod)
          mod.send(:attr_accessor, :installation_options)

          def mod.delegate_installation_options(&blk)
            define_method(:installation_options) do
              @installation_options ||= InstallationOptions.from_podfile(instance_eval(&blk))
            end
          end

          def mod.delegate_installation_option_attributes!
            define_method(:respond_to_missing?) do |name, *args|
              installation_options.respond_to?(name, *args) || super
            end

            define_method(:method_missing) do |name, *args, &blk|
              if installation_options.respond_to?(name)
                installation_options.send(name, *args, &blk)
              else
                super
              end
            end
          end
        end
      end
    end
  end
end
