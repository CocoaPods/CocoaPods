module Pod
  module Generator
    module XCConfig
      # Generates the xcconfigs for the aggregate targets.
      #
      class AggregateXCConfig
        # @return [Target] the target represented by this xcconfig.
        #
        attr_reader :target

        # @param  [Target] target @see target
        #
        # @param  [String] configuration_name
        #         The name of the build configuration to generate this xcconfig
        #         for.
        #
        def initialize(target, configuration_name)
          @target = target
          @configuration_name = configuration_name
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
        # @note   The xcconfig file for a Pods integration target includes the
        #         namespaced xcconfig files for each spec target dependency.
        #         Each namespaced configuration value is merged into the Pod
        #         xcconfig file.
        #
        # @todo   This doesn't include the specs xcconfigs anymore and now the
        #         logic is duplicated.
        #
        # @return [Xcodeproj::Config]
        #
        def generate
          pod_targets = target.pod_targets_for_build_configuration(@configuration_name)
          config = {
            'OTHER_LDFLAGS' => XCConfigHelper.default_ld_flags(target),
            'OTHER_LIBTOOLFLAGS' => '$(OTHER_LDFLAGS)',
            'PODS_ROOT' => target.relative_pods_root,
            'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) COCOAPODS=1',
          }

          if target.requires_frameworks?
            # Framework headers are automatically discoverable by `#import <…>`.
            header_search_paths = pod_targets.map { |target| "$PODS_FRAMEWORK_BUILD_PATH/#{target.product_name}/Headers" }
            build_settings = {
              'PODS_FRAMEWORK_BUILD_PATH' => target.configuration_build_dir,
              'FRAMEWORK_SEARCH_PATHS' => '"$PODS_FRAMEWORK_BUILD_PATH"',
              # Make headers discoverable by `import "…"`
              'OTHER_CFLAGS' => '$(inherited) ' + XCConfigHelper.quote(header_search_paths, '-iquote')
            }
            config.merge!(build_settings)
          else
            # Make headers discoverable from $PODS_ROOT/Headers directory
            header_search_paths = target.sandbox.public_headers.search_paths(target.platform)
            build_settings = {
              # by `import "…"`
              'HEADER_SEARCH_PATHS' => XCConfigHelper.quote(header_search_paths),
              # by `#import <…>`
              'OTHER_CFLAGS' => '$(inherited) ' + XCConfigHelper.quote(header_search_paths, '-isystem')
            }
            config.merge!(build_settings)
          end

          @xcconfig = Xcodeproj::Config.new(config)

          XCConfigHelper.add_target_specific_settings(target, @xcconfig)

          pod_targets.each do |pod_target|
            XCConfigHelper.add_settings_for_file_accessors_of_target(pod_target, @xcconfig)

            # Add pod target to list of frameworks / libraries that are
            # linked with the user’s project.
            if pod_target.requires_frameworks?
              @xcconfig.merge!('OTHER_LDFLAGS' => %(-framework "#{pod_target.product_basename}"))
            else
              @xcconfig.merge!('OTHER_LDFLAGS' => %(-l "#{pod_target.product_basename}"))
            end
          end

          # TODO Need to decide how we are going to ensure settings like these
          # are always excluded from the user's project.
          #
          # See https://github.com/CocoaPods/CocoaPods/issues/1216
          @xcconfig.attributes.delete('USE_HEADERMAP')

          @xcconfig
        end

        #---------------------------------------------------------------------#
      end
  end
end
end
