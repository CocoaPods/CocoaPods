module Pod
  module Generator

    #
    class AggregateXCConfig < XCConfig

      # Generates the xcconfig for the Pod integration target.
      #
      # @note   The xcconfig file for a Pods integration target includes the
      #         namespaced xcconfig files for each spec target dependency.
      #         Each namespaced configuration value is merged into the Pod
      #         xcconfig file.
      #
      # @return [Xcodeproj::Config]
      #
      def generate
        ld_flags = '-ObjC'
        if target.target_definition.podfile.set_arc_compatibility_flag?
          ld_flags << ' -fobjc-arc'
        end

        config = {
          'ALWAYS_SEARCH_USER_PATHS'         => 'YES',
          'OTHER_LDFLAGS'                    => ld_flags,
          'HEADER_SEARCH_PATHS'              => quote(sandbox.public_headers.search_paths),
          'PODS_ROOT'                        => target.relative_pods_root,
          'GCC_PREPROCESSOR_DEFINITIONS'     => '$(inherited) COCOAPODS=1',
        }

        target.pod_targets.each do |lib|
          consumer_xcconfig(lib.consumer).to_hash.each do |k, v|
            prefixed_key = lib.xcconfig_prefix + k
            config[k] = "#{config[k]} ${#{prefixed_key}}"
          end
        end

        @xcconfig = Xcodeproj::Config.new(config)
        @xcconfig.includes = target.pod_targets.map(&:name)
        @xcconfig
      end

      #-----------------------------------------------------------------------#

    end
  end
end
