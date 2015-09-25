module Pod
  module Generator
    module XCConfig
      # Generates the private xcconfigs for the pod targets.
      #
      # The xcconfig file for a Pod target merges the pod target
      # configuration values with the default configuration values
      # required by CocoaPods.
      #
      class PodXCConfig
        # @return [Target] the target represented by this xcconfig.
        #
        attr_reader :target

        # Initialize a new instance
        #
        # @param  [Target] target @see target
        #
        def initialize(target)
          @target = target
        end

        # @return [Xcodeproj::Config] The generated xcconfig.
        #
        attr_reader :xcconfig

        # Generates and saves the xcconfig to the given path.
        #
        # @param  [Pathname] path
        #         the path where the prefix header should be stored.
        #
        # @return [void]
        #
        def save_as(path)
          generate.save_as(path)
        end

        # Generates the xcconfig.
        #
        # @return [Xcodeproj::Config]
        #
        def generate
          target_search_paths = target.build_headers.search_paths(target.platform)
          sandbox_search_paths = target.sandbox.public_headers.search_paths(target.platform)
          search_paths = target_search_paths.concat(sandbox_search_paths).uniq

          config = {
            'OTHER_LDFLAGS' => XCConfigHelper.default_ld_flags(target),
            'PODS_ROOT' => '${SRCROOT}',
            'HEADER_SEARCH_PATHS' => XCConfigHelper.quote(search_paths),
            'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) COCOAPODS=1',
            'SKIP_INSTALL' => 'YES',
            'FRAMEWORK_SEARCH_PATHS' => '$(inherited) '
            # 'USE_HEADERMAP' => 'NO'
          }

          @xcconfig = Xcodeproj::Config.new(config)

          if target.requires_frameworks? && target.scoped?
            # Only quote the FRAMEWORK_SEARCH_PATHS entry, because it’s a setting that takes multiple values.
            # In addition, quoting CONFIGURATION_BUILD_DIR would make it be interpreted as a relative path.
            build_settings = {
              'PODS_FRAMEWORK_BUILD_PATH' => target.configuration_build_dir,
              'FRAMEWORK_SEARCH_PATHS' => '"$PODS_FRAMEWORK_BUILD_PATH"',
              'CONFIGURATION_BUILD_DIR' => '$PODS_FRAMEWORK_BUILD_PATH',
            }
            @xcconfig.merge!(build_settings)
          end

          XCConfigHelper.add_settings_for_file_accessors_of_target(target, @xcconfig)
          target.file_accessors.each do |file_accessor|
            @xcconfig.merge!(file_accessor.spec_consumer.pod_target_xcconfig)
          end
          XCConfigHelper.add_target_specific_settings(target, @xcconfig)
          @xcconfig
        end

        #-----------------------------------------------------------------------#
      end
    end
  end
end
