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
        # @param  [Boolean] test_xcconfig
        #         whether this is an xcconfig for a test native target.
        #
        def initialize(target, test_xcconfig = false)
          @target = target
          @test_xcconfig = test_xcconfig
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
            'HEADER_SEARCH_PATHS' => '$(inherited) ' + XCConfigHelper.quote(target.header_search_paths(@test_xcconfig)),
            'LIBRARY_SEARCH_PATHS' => '$(inherited) ',
            'OTHER_CFLAGS' => '$(inherited) ',
            'OTHER_LDFLAGS' => XCConfigHelper.default_ld_flags(target, @test_xcconfig),
            'OTHER_SWIFT_FLAGS' => '$(inherited) ',
            'PODS_ROOT' => '${SRCROOT}',
            'PODS_TARGET_SRCROOT' => target.pod_target_srcroot,
            'PRODUCT_BUNDLE_IDENTIFIER' => 'org.cocoapods.${PRODUCT_NAME:rfc1034identifier}',
            'SKIP_INSTALL' => 'YES',
            'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) ',
            'SWIFT_INCLUDE_PATHS' => '$(inherited) ',
          }

          @xcconfig = Xcodeproj::Config.new(config)

          XCConfigHelper.add_settings_for_file_accessors_of_target(nil, target, @xcconfig, true, @test_xcconfig)
          target.file_accessors.each do |file_accessor|
            @xcconfig.merge!(file_accessor.spec_consumer.pod_target_xcconfig) if @test_xcconfig == file_accessor.spec.test_specification?
          end
          XCConfigHelper.add_target_specific_settings(target, @xcconfig)
          recursive_dependent_targets = target.recursive_dependent_targets
          @xcconfig.merge! XCConfigHelper.search_paths_for_dependent_targets(target, recursive_dependent_targets, @test_xcconfig)
          XCConfigHelper.generate_vendored_build_settings(target, recursive_dependent_targets, @xcconfig, false, @test_xcconfig)
          if @test_xcconfig
            test_dependent_targets = [target, *target.recursive_test_dependent_targets].uniq
            @xcconfig.merge! XCConfigHelper.search_paths_for_dependent_targets(target, test_dependent_targets - recursive_dependent_targets, @test_xcconfig)
            XCConfigHelper.generate_vendored_build_settings(nil, target.all_dependent_targets, @xcconfig, true, @test_xcconfig)
            XCConfigHelper.generate_other_ld_flags(nil, target.all_dependent_targets, @xcconfig)
            XCConfigHelper.generate_ld_runpath_search_paths(target, false, true, @xcconfig)
          end
          @xcconfig
        end

        #-----------------------------------------------------------------------#
      end
    end
  end
end
