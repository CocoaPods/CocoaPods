require 'active_support/hash_with_indifferent_access'

module Pod
  class Installer
    # Represents the installation options the user can customize via a
    # `Podfile`.
    #
    class InstallationOptions
      # Parses installation options from a podfile.
      #
      # @param  [Podfile] podfile the podfile to parse installation options
      #         from.
      #
      # @raise  [Informative] if `podfile` does not specify a `CocoaPods`
      #         install.
      #
      # @return [Self]
      #
      def self.from_podfile(podfile)
        name, options = podfile.installation_method
        unless name.downcase == 'cocoapods'
          raise Informative, "Currently need to specify a `cocoapods` install, you chose `#{name}`."
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

      # @return [Hash<Symbol,Object>] all known installation options and their
      #         default values.
      #
      def self.defaults
        @defaults ||= {}
      end

      # @return [Array<Symbol>] the names of all known installation options.
      #
      def self.all_options
        defaults.keys
      end

      # Initializes the installation options with a hash of options from a
      # Podfile.
      #
      # @param  [Hash] options the options to parse.
      #
      # @raise  [Informative] if `options` contains any unknown keys.
      #
      def initialize(options = {})
        options = ActiveSupport::HashWithIndifferentAccess.new(options)
        unknown_keys = options.keys - self.class.all_options.map(&:to_s)
        raise Informative, "Unknown installation options: #{unknown_keys.to_sentence}." unless unknown_keys.empty?
        self.class.defaults.each do |key, default|
          value = options.fetch(key, default)
          send("#{key}=", value)
        end
      end

      # @param  [Boolean] include_defaults whether values that match the default
      #         for their option should be included. Defaults to `true`.
      #
      # @return [Hash] the options, keyed by option name.
      #
      def to_h(include_defaults: true)
        self.class.defaults.reduce(ActiveSupport::HashWithIndifferentAccess.new) do |hash, (option, default)|
          value = send(option)
          hash[option] = value if include_defaults || value != default
          hash
        end
      end

      def ==(other)
        other.is_a?(self.class) && to_h == other.to_h
      end

      alias_method :eql, :==

      def hash
        to_h.hash
      end

      option :clean, true
      option :deduplicate_targets, true
      option :deterministic_uuids, true
      option :integrate_targets, true
      option :lock_pod_sources, true
      option :warn_for_multiple_pod_sources, true
      option :share_schemes_for_development_pods, false

      module Mixin
        module ClassMethods
          # Delegates the creation of {#installation_options} to the `Podfile`
          # returned by the given block.
          #
          # @param  blk a block that returns the `Podfile` to create
          #         installation options from.
          #
          # @return [Void]
          #
          def delegate_installation_options(&blk)
            define_method(:installation_options) do
              @installation_options ||= InstallationOptions.from_podfile(instance_eval(&blk))
            end
          end

          # Delegates the installation options attributes directly to
          # {#installation_options}.
          #
          # @return [Void]
          #
          def delegate_installation_option_attributes!
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

        # @return [InstallationOptions] The installation options.
        #
        attr_accessor :installation_options

        def self.included(mod)
          mod.extend(ClassMethods)
        end
      end
    end
  end
end
