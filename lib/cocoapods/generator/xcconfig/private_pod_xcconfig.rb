module Pod
  module Generator

    # Generates the private xcconfigs for the pod targets.
    #
    # The private xcconfig file for a Pod target merges the configuration
    # values of the public namespaced xcconfig with the default private
    # configuration values required by CocoaPods.
    #
    class PrivatePodXCConfig < XCConfig

      # @return [Xcodeproj::Config] The public xcconfig which this one will
      #         use.
      #
      attr_reader :public_xcconfig

      # @param  [Target] target @see target
      # @param  [Xcodeproj::Config] public_xcconfig @see public_xcconfig
      #
      def initialize(target, public_xcconfig)
        super(target)
        @public_xcconfig = public_xcconfig
      end

      # Generates the xcconfig.
      #
      # @return [Xcodeproj::Config]
      #
      def generate
        config = {
          'OTHER_LDFLAGS'                => default_ld_flags,
          'PODS_ROOT'                    => '${SRCROOT}',
          'HEADER_SEARCH_PATHS'          => quote(target.build_headers.search_paths) + ' ' + quote(sandbox.public_headers.search_paths),
          'GCC_PREPROCESSOR_DEFINITIONS' => 'COCOAPODS=1',
          # 'USE_HEADERMAP'                => 'NO'
        }

        xcconfig_hash = add_xcconfig_namespaced_keys(public_xcconfig.to_hash, config, target.xcconfig_prefix)
        @xcconfig = Xcodeproj::Config.new(xcconfig_hash)
        @xcconfig.includes = [target.name]
        @xcconfig
      end

      private

      #-----------------------------------------------------------------------#

      # !@group Private Helpers

      # Returns the hash representation of an xcconfig which inherit from the
      # namespaced keys of a given one.
      #
      # @param  [Hash] source_config
      #         The xcconfig whose keys need to be inherited.
      #
      # @param  [Hash] destination_config
      #         The config which should inherit the source config keys.
      #
      # @return [Hash] The inheriting xcconfig.
      #
      def add_xcconfig_namespaced_keys(source_config, destination_config, prefix)
        result = destination_config.dup
        source_config.each do |key, value|
          prefixed_key = prefix + conditional_less_key(key)
          current_value = destination_config[key]
          if current_value
            result[key] = "#{current_value} ${#{prefixed_key}}"
          else
            result[key] = "${#{prefixed_key}}"
          end
        end
        result
      end

      # Strips the [*]-syntax from the given xcconfig key.
      #
      # @param  [String] key
      #         The key to strip.
      #
      # @return [String] The stripped key.
      #
      def conditional_less_key(key)
        brackets_index = key.index('[')
        if brackets_index
          key[0...brackets_index]
        else
          key
        end
      end

      #-----------------------------------------------------------------------#

    end
  end
end
