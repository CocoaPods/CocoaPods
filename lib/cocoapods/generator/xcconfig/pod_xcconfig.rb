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
          config = {
            'FRAMEWORK_SEARCH_PATHS' => '$(inherited) ',
            'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) COCOAPODS=1',
            'HEADER_SEARCH_PATHS' => XCConfigHelper.quote(target.target_header_search_paths),
            'LIBRARY_SEARCH_PATHS' => '$(inherited) ',
            'OTHER_LDFLAGS' => XCConfigHelper.default_ld_flags(target),
            'PODS_ROOT' => '${SRCROOT}',
            'PRODUCT_BUNDLE_IDENTIFIER' => 'org.cocoapods.${PRODUCT_NAME:rfc1034identifier}',
            'SKIP_INSTALL' => 'YES',
            # 'USE_HEADERMAP' => 'NO'
          }

          @xcconfig = Xcodeproj::Config.new(config)

          XCConfigHelper.add_settings_for_file_accessors_of_target(target, @xcconfig)
          target.file_accessors.each do |file_accessor|
            @xcconfig.merge!(file_accessor.spec_consumer.pod_target_xcconfig)
          end
          XCConfigHelper.add_target_specific_settings(target, @xcconfig)
          @xcconfig.merge! XCConfigHelper.settings_for_dependent_targets(target, target.recursive_dependent_targets)
          @xcconfig
        end

        #-----------------------------------------------------------------------#
      end
    end
  end
end
