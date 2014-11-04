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
          header_search_path_flags = target.sandbox.public_headers.search_paths(target.platform)
          config = {
            'OTHER_LDFLAGS' => XCConfigHelper.default_ld_flags(target),
            'OTHER_LIBTOOLFLAGS' => '$(OTHER_LDFLAGS)',
            'HEADER_SEARCH_PATHS' => XCConfigHelper.quote(header_search_path_flags),
            'PODS_ROOT' => target.relative_pods_root,
            'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) COCOAPODS=1',
            'OTHER_CFLAGS' => '$(inherited) ' + XCConfigHelper.quote(header_search_path_flags, '-isystem')
          }

          if target.requires_framework?
            build_settings = {
              'FRAMEWORK_SEARCH_PATHS' => XCConfigHelper.quote([target.configuration_build_dir]),
            }
            config.merge!(build_settings)
          end

          @xcconfig = Xcodeproj::Config.new(config)

          XCConfigHelper.add_target_specific_settings(target, @xcconfig)

          target.pod_targets.each do |pod_target|
            next unless pod_target.include_in_build_config?(@configuration_name)

            pod_target.file_accessors.each do |file_accessor|
              XCConfigHelper.add_spec_build_settings_to_xcconfig(file_accessor.spec_consumer, @xcconfig)
              file_accessor.vendored_frameworks.each do |vendored_framework|
                XCConfigHelper.add_framework_build_settings(vendored_framework, @xcconfig, target.sandbox.root)
              end
              file_accessor.vendored_libraries.each do |vendored_library|
                XCConfigHelper.add_library_build_settings(vendored_library, @xcconfig, target.sandbox.root)
              end
            end

            # Add pod framework to list of frameworks / libraries that are
            # linked with the user’s project.
            if pod_target.requires_framework?
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
