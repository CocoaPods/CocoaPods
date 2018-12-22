module Pod
  class Installer
    module ProjectCache
      # Uniquely identifies a Target.
      #
      class TargetCacheKey
        require 'cocoapods/target/pod_target.rb'
        require 'cocoapods/target/aggregate_target.rb'
        require 'digest'

        # @return [Symbol]
        #         The type of target. Either aggregate or pod target.
        #
        attr_reader :type

        # @return [Hash{String => Object}]
        #         The hash containing key-value pairs that identify the target.
        #
        attr_reader :hash

        # Initialize a new instance.
        #
        # @param [Symbol] type @see #type
        # @param [Hash{String => Object}] hash @see #hash
        #
        def initialize(type, hash)
          @type = type
          @hash = hash
        end

        # Equality function used to compare TargetCacheKey objects to each other.
        #
        # @param [TargetCacheKey] other
        #        Other object to compare itself against.
        #
        # @return [Symbol] The difference between this and another TargetCacheKey object.
        #         # Symbol :none means no difference.
        #
        def key_difference(other)
          if other.type != type
            :project
          else
            case type
            when :pod_target
              return :project if (other.hash.keys - hash.keys).any?
              return :project if other.hash['CHECKSUM'] != hash['CHECKSUM']
              return :project if other.hash['SPECS'] != hash['SPECS']
              return :project if other.hash['FILES'] != hash['FILES']
            end

            this_build_settings = hash['BUILD_SETTINGS_CHECKSUM']
            other_build_settings = other.hash['BUILD_SETTINGS_CHECKSUM']
            return :project if this_build_settings != other_build_settings

            this_checkout_options = hash['CHECKOUT_OPTIONS']
            other_checkout_options = other.hash['CHECKOUT_OPTIONS']
            return :project if this_checkout_options != other_checkout_options

            :none
          end
        end

        def to_h
          hash
        end

        # Creates a TargetCacheKey instance from the given hash.
        #
        # @param [Hash{String => Object}] hash
        #        The hash used to construct a TargetCacheKey object.
        #
        # @return [TargetCacheKey]
        #
        def self.from_cache_hash(hash)
          if files = hash['FILES']
            hash['FILES'] = files.sort
          end
          type = hash['CHECKSUM'] ? :pod_target : :aggregate
          TargetCacheKey.new(type, hash)
        end


        # Constructs a TargetCacheKey instance from a PodTarget.
        #
        # @param [PodTarget] pod_target
        #        The pod target used to construct a TargetCacheKey object.
        #
        # @param [Bool] is_local_pod
        #        Used to also include its local files in the cache key.
        #
        # @param [Hash] checkout_options
        #        The checkout options for this pod target.
        #
        # @return [TargetCacheKey]
        #
        def self.from_pod_target(pod_target, is_local_pod: false, checkout_options: nil)
          build_settings = {}
          build_settings[pod_target.label.to_s] = Digest::MD5.hexdigest(pod_target.build_settings.xcconfig.to_s)
          pod_target.test_spec_build_settings.each do |name, settings|
            build_settings[name] = Digest::MD5.hexdigest(settings.xcconfig.to_s)
          end
          pod_target.app_spec_build_settings.each do |name, settings|
            build_settings[name] = Digest::MD5.hexdigest(settings.xcconfig.to_s)
          end

          contents = {
            'CHECKSUM' => pod_target.root_spec.checksum,
            'SPECS' => pod_target.specs.map(&:to_s),
            'BUILD_SETTINGS_CHECKSUM' => build_settings,
          }
          contents['FILES'] = pod_target.all_files.sort if is_local_pod
          contents['CHECKOUT_OPTIONS'] = checkout_options if checkout_options
          TargetCacheKey.new(:pod_target, contents)
        end

        # Construct a TargetCacheKey instance from an AggregateTarget.
        #
        # @param [AggregateTarget] aggregate_target
        #        The aggregate target used to construct a TargetCacheKey object.
        #
        # @return [TargetCacheKey]
        #
        def self.from_aggregate_target(aggregate_target)
          build_settings = {}
          aggregate_target.user_build_configurations.keys.each do |configuration|
            build_settings[configuration] = Digest::MD5.hexdigest(aggregate_target.build_settings(configuration).xcconfig.to_s)
          end

          TargetCacheKey.new(:aggregate, 'BUILD_SETTINGS_CHECKSUM' => build_settings)
        end
      end
    end
  end
end
