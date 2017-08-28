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
        # @param  [Specification] test_spec
        #         If not `nil` then this xcconfig is for a test specification.
        #
        def initialize(target, test_spec = nil)
          @target = target
          @test_spec = test_spec
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
            'FRAMEWORK_SEARCH_PATHS' => '$(inherited) ',
            'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) COCOAPODS=1',
            'HEADER_SEARCH_PATHS' => XCConfigHelper.quote(search_paths),
            'LIBRARY_SEARCH_PATHS' => '$(inherited) ',
            'OTHER_LDFLAGS' => XCConfigHelper.default_ld_flags(target, !@test_spec.nil?),
            'PODS_ROOT' => '${SRCROOT}',
            'PODS_TARGET_SRCROOT' => target.pod_target_srcroot,
            'PRODUCT_BUNDLE_IDENTIFIER' => 'org.cocoapods.${PRODUCT_NAME:rfc1034identifier}',
            'SKIP_INSTALL' => 'YES',
            'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) ',
            # 'USE_HEADERMAP' => 'NO'
          }

          @xcconfig = Xcodeproj::Config.new(config)

          XCConfigHelper.add_settings_for_file_accessors_of_target(nil, target, @xcconfig)
          target.file_accessors.each do |file_accessor|
            @xcconfig.merge!(file_accessor.spec_consumer.pod_target_xcconfig)
          end
          XCConfigHelper.add_target_specific_settings(target, @xcconfig)
          recursive_dependent_targets = target.recursive_dependent_targets
          @xcconfig.merge! XCConfigHelper.settings_for_dependent_targets(target, recursive_dependent_targets, !@test_spec.nil?)
          unless @test_spec.nil?
            test_dependent_targets = target.test_dependent_targets_for_test_spec(@test_spec)
            @xcconfig.merge! XCConfigHelper.settings_for_dependent_targets(target, test_dependent_targets - recursive_dependent_targets, !@test_spec.nil?)
            XCConfigHelper.generate_vendored_build_settings(nil, test_dependent_targets, @xcconfig)
            XCConfigHelper.generate_other_ld_flags(nil, test_dependent_targets, @xcconfig)
            XCConfigHelper.generate_ld_runpath_search_paths(target, false, true, @xcconfig)
          end
          @xcconfig
        end

        #-----------------------------------------------------------------------#
      end
    end
  end
end
