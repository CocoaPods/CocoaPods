module Pod
  module Generator

    #
    class PrivatePodXCConfig < XCConfig

      # Generates the xcconfig for the target.
      #
      # @note   The private xcconfig file for a spec target includes the public
      #         namespaced xcconfig file and merges the configuration values
      #         with the default private configuration values.
      #
      # @return [Xcodeproj::Config]
      #
      def generate
        config = {
          'ALWAYS_SEARCH_USER_PATHS'     => 'YES',
          'OTHER_LDFLAGS'                => default_ld_flags,
          'PODS_ROOT'                    => '${SRCROOT}',
          'HEADER_SEARCH_PATHS'          => quote(target.build_headers.search_paths) + ' ' + quote(sandbox.public_headers.search_paths),
          'GCC_PREPROCESSOR_DEFINITIONS' => 'COCOAPODS=1',
          # 'USE_HEADERMAP'                => 'NO'
        }

        xcconfig = Xcodeproj::Config.new
        target.spec_consumers.each do |consumer|
          add_spec_build_settings_to_xcconfig(consumer, xcconfig)
        end

        xcconfig.to_hash.each do |k, v|
          prefixed_key = target.xcconfig_prefix + k
          config[k] = "#{config[k]} ${#{prefixed_key}}"
        end

        @xcconfig = Xcodeproj::Config.new(config)
        @xcconfig.includes = [target.name]
        @xcconfig
      end

      #-----------------------------------------------------------------------#

    end
  end
end
