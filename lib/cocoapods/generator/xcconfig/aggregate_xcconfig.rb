module Pod
  module Generator

    # Generates the xcconfigs for the aggregate targets.
    #
    class AggregateXCConfig < XCConfig

      # Generates the xcconfig.
      #
      # @note   The xcconfig file for a Pods integration target includes the
      #         namespaced xcconfig files for each spec target dependency.
      #         Each namespaced configuration value is merged into the Pod
      #         xcconfig file.
      #
      # @return [Xcodeproj::Config]
      #
      def generate
        @xcconfig = Xcodeproj::Config.new({
          'OTHER_LDFLAGS'                => default_ld_flags,
          'HEADER_SEARCH_PATHS'          => quote(sandbox.public_headers.search_paths),
          'PODS_ROOT'                    => target.relative_pods_root,
          'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) COCOAPODS=1',
        })

        target.pod_targets.each do |pod_target|
          pod_target.spec_consumers.each do |consumer|
            add_spec_build_settings_to_xcconfig(consumer, @xcconfig)
          end
        end

        # TODO Need to decide how we are going to ensure settings like these
        # are always excluded from the user's project.
        #
        # See https://github.com/CocoaPods/CocoaPods/issues/1216
        @xcconfig.attributes.delete('USE_HEADERMAP')

        @xcconfig
      end

      #-----------------------------------------------------------------------#

    end
  end
end
