module Pod
  module Generator
    module XCConfig

      # Generates the xcconfigs for the aggregate targets.
      #
      class AggregateXCConfig

        # @return [Target] the target represented by this xcconfig.
        #
        attr_reader :target
        attr_reader :sandbox_root

        # @param  [Target] target @see target
        #
        def initialize(target, sandbox_root)
          @target = target
          @sandbox_root = sandbox_root
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
          @xcconfig = Xcodeproj::Config.new({
            'OTHER_LDFLAGS' => XCConfigHelper.default_ld_flags(target),
            'HEADER_SEARCH_PATHS' => XCConfigHelper.quote(target.public_headers_store.search_paths),
            'PODS_ROOT' => relative_pods_root,
            'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) COCOAPODS=1',
          })

          target.children.each do |pod_target|
            pod_target.file_accessors.each do |file_accessor|
              XCConfigHelper.add_spec_build_settings_to_xcconfig(file_accessor.spec_consumer, @xcconfig)
              file_accessor.vendored_frameworks.each do |vendored_framework|
                XCConfigHelper.add_framework_build_settings(vendored_framework, @xcconfig, sandbox_root)
              end
              file_accessor.vendored_libraries.each do |vendored_library|
                XCConfigHelper.add_library_build_settings(vendored_library, @xcconfig, sandbox_root)
              end
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

        # @return [String] The xcconfig path of the root from the `$(SRCROOT)`
        #         variable of the user's project.
        #
        #         TODO: return the root of the sandbox
        #         The pods root is used by the copy resources script
        #
        def relative_pods_root
          if target.user_project_path
            "${SRCROOT}/#{sandbox_root.relative_path_from(target.user_project_path.dirname)}"
          else
            sandbox_root
          end
        end

        #-----------------------------------------------------------------------#

      end
    end
  end
end
