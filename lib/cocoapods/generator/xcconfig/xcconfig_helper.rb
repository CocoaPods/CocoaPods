module Pod
  module Generator
    module XCConfig

      # Stores the shared logic of the classes of the XCConfig module.
      #
      module XCConfigHelper

        # Converts an array of strings to a single string where the each string
        # is surrounded by double quotes and separated by a space. Used to
        # represent strings in a xcconfig file.
        #
        # @param  [Array<String>] strings
        #         a list of strings.
        #
        # @return [String] the resulting string.
        #
        def self.quote(strings)
          strings.sort.map { |s| %W|"#{s}"| }.join(" ")
        end

        # @return [String] the default linker flags. `-ObjC` is always included
        #         while `-fobjc-arc` is included only if requested in the
        #         Podfile.
        #
        def self.default_ld_flags(target)
          ld_flags = '-ObjC'
          if target.target_definition.podfile.set_arc_compatibility_flag? and
            target.spec_consumers.any? { |consumer| consumer.requires_arc? }
            ld_flags << ' -fobjc-arc'
          end
          ld_flags
        end

        # Configures the given Xcconfig according to the build settings of the
        # given Specification.
        #
        # @param  [Specification::Consumer] consumer
        #         The consumer of the specification.
        #
        # @param  [Xcodeproj::Config] xcconfig
        #         The xcconfig to edit.
        #
        def self.add_spec_build_settings_to_xcconfig(consumer, xcconfig)
          xcconfig.merge!(consumer.xcconfig)
          xcconfig.libraries.merge(consumer.libraries)
          xcconfig.frameworks.merge(consumer.frameworks)
          xcconfig.weak_frameworks.merge(consumer.weak_frameworks)
          add_developers_frameworks_if_needed(xcconfig)
        end

        # Configures the given Xcconfig with the the build settings for the given
        # framework path.
        #
        # @param  [Pathanme] framework_path
        #         The path of the framework.
        #
        # @param  [Xcodeproj::Config] xcconfig
        #         The xcconfig to edit.
        #
        def self.add_framework_build_settings(framework_path, xcconfig, sandbox_root)
          name = File.basename(framework_path, ".framework")
          dirname = File.dirname(framework_path).sub(sandbox_root.to_s, '$(PODS_ROOT)')
          build_settings = {
            'OTHER_LDFLAGS' => "-framework #{name}",
            'FRAMEWORK_SEARCH_PATHS' => quote([dirname])
          }
          xcconfig.merge!(build_settings)
        end

        # Configures the given Xcconfig with the the build settings for the given
        # framework path.
        #
        # @param  [Pathanme] framework_path
        #         The path of the framework.
        #
        # @param  [Xcodeproj::Config] xcconfig
        #         The xcconfig to edit.
        #
        def self.add_library_build_settings(library_path, xcconfig, sandbox_root)
          name = File.basename(library_path, ".a").sub(/\Alib/, '')
          dirname = File.dirname(library_path).sub(sandbox_root.to_s, '$(PODS_ROOT)')
          build_settings = {
            'OTHER_LDFLAGS' => "-l#{name}",
            'LIBRARY_SEARCH_PATHS' => quote([dirname])
          }
          xcconfig.merge!(build_settings)
        end

        # @return [Array<String>] The search paths for the developer frameworks.
        #
        DEVELOPER_FRAMEWORKS_SEARCH_PATHS = [
          '$(inherited)',
          '"$(SDKROOT)/Developer/Library/Frameworks"',
          '"$(DEVELOPER_LIBRARY_DIR)/Frameworks"'
        ]

        # Adds the search paths of the developer frameworks to the specification
        # if needed. This is done because the `SenTestingKit` requires them and
        # adding them to each specification which requires it is repetitive and
        # error prone.
        #
        # @param  [Xcodeproj::Config] xcconfig
        #         The xcconfig to edit.
        #
        # @return [void]
        #
        def self.add_developers_frameworks_if_needed(xcconfig)
          if xcconfig.frameworks.include?('SenTestingKit')
            search_paths = xcconfig.attributes['FRAMEWORK_SEARCH_PATHS'] ||= ''
            DEVELOPER_FRAMEWORKS_SEARCH_PATHS.each do |search_path|
              unless search_paths.include?(search_path)
                search_paths << ' ' unless search_paths.empty?
                search_paths << search_path
              end
            end
          end
        end

        #---------------------------------------------------------------------#
      end
    end
  end
end
