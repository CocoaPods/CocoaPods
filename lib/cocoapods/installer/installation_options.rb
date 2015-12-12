require 'active_support/hash_with_indifferent_access'

module Pod
  class Installer
    class InstallationOptions
      def self.from_podfile(podfile)
        name = podfile.installation_method['name']
        unless name.downcase == 'cocoapods'
          raise Informative "currently need to specify a cocoapods install, you chose #{name}"
        end
        options = podfile.installation_method['options']
        new(options)
      end

      def self.option(name, default, boolean: true)
        name = name.to_s
        raise 'existing' if defaults.key?(name)
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
        end

        def respond_to_missing?(name, *args)
          installation_options.respond_to?(name, *args) || super
        end

        def method_missing(name, *args, &blk)
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
