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
        if aggregate_target.target_definition.podfile.set_arc_compatibility_flag?
          ld_flags << ' -fobjc-arc'
        end

        config = {
          'ALWAYS_SEARCH_USER_PATHS'         => 'YES',
          'OTHER_LDFLAGS'                    => ld_flags,
          'HEADER_SEARCH_PATHS'              => quote(sandbox.public_headers.search_paths),
          'PODS_ROOT'                        => aggregate_target.relative_pods_root,
          'GCC_PREPROCESSOR_DEFINITIONS'     => '$(inherited) COCOAPODS=1',
        }

        aggregate_target.pod_targets.each do |lib|
          consumer_xcconfig(lib.consumer).to_hash.each do |k, v|
            prefixed_key = lib.xcconfig_prefix + k
            config[k] = "#{config[k]} ${#{prefixed_key}}"
          end
        end

        @xcconfig = Xcodeproj::Config.new(config)
        @xcconfig.includes = aggregate_target.pod_targets.map(&:name)
        @xcconfig
      end

      #-----------------------------------------------------------------------#

    end
  end
end
