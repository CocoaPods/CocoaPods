module Pod
  module Generator

    # Generates the private xcconfigs for the pod targets.
    #
    # The private xcconfig file for a Pod target merges the configuration
    # values of the public namespaced xcconfig with the default private
    # configuration values required by CocoaPods.
    #
    class PrivatePodXCConfig < XCConfig

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
