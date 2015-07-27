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
        # @param  [String] prefix
        #         optional prefix, such as a flag or option.
        #
        # @return [String] the resulting string.
        #
        def self.quote(strings, prefix = nil)
          prefix = "#{prefix} " if prefix
          strings.sort.map { |s| %W(          #{prefix}"#{s}"          ) }.join(' ')
        end

        # Return the default linker flags
        #
        # @param  [Target] target
        #         the target, which is used to check if the ARC compatibility
        #         flag is required.
        #
        # @return [String] the default linker flags. `-ObjC` is always included
        #         while `-fobjc-arc` is included only if requested in the
        #         Podfile.
        #
        def self.default_ld_flags(target, includes_static_libraries = false)
          ld_flags = ''
          ld_flags << '-ObjC' if includes_static_libraries
          if target.podfile.set_arc_compatibility_flag? &&
              target.spec_consumers.any?(&:requires_arc?)
            ld_flags << ' -fobjc-arc'
          end
          ld_flags.strip
        end

        # Configures the given Xcconfig
        #
        # @param  [PodTarget] target
        #         The pod target, which holds the list of +Spec::FileAccessor+.
        #
        # @param  [Xcodeproj::Config] xcconfig
        #         The xcconfig to edit.
        #
        def self.add_settings_for_file_accessors_of_target(target, xcconfig)
          target.file_accessors.each do |file_accessor|
            XCConfigHelper.add_spec_build_settings_to_xcconfig(file_accessor.spec_consumer, xcconfig)
            file_accessor.vendored_frameworks.each do |vendored_framework|
              XCConfigHelper.add_framework_build_settings(vendored_framework, xcconfig, target.sandbox.root)
            end
            file_accessor.vendored_libraries.each do |vendored_library|
              XCConfigHelper.add_library_build_settings(vendored_library, xcconfig, target.sandbox.root)
            end
          end
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
          xcconfig.libraries.merge(consumer.libraries)
          xcconfig.frameworks.merge(consumer.frameworks)
          xcconfig.weak_frameworks.merge(consumer.weak_frameworks)
          add_developers_frameworks_if_needed(xcconfig, consumer.platform_name)
        end

        # Configures the given Xcconfig with the build settings for the given
        # framework path.
        #
        # @param  [Pathname] framework_path
        #         The path of the framework.
        #
        # @param  [Xcodeproj::Config] xcconfig
        #         The xcconfig to edit.
        #
        # @param  [Pathname] sandbox_root
        #         The path retrieved from Sandbox#root.
        #
        def self.add_framework_build_settings(framework_path, xcconfig, sandbox_root)
          name = File.basename(framework_path, '.framework')
          dirname = '$(PODS_ROOT)/' + framework_path.dirname.relative_path_from(sandbox_root).to_s
          build_settings = {
            'OTHER_LDFLAGS' => "-framework #{name}",
            'FRAMEWORK_SEARCH_PATHS' => quote([dirname]),
          }
          xcconfig.merge!(build_settings)
        end

        # Configures the given Xcconfig with the build settings for the given
        # library path.
        #
        # @param  [Pathname] library_path
        #         The path of the library.
        #
        # @param  [Xcodeproj::Config] xcconfig
        #         The xcconfig to edit.
        #
        # @param  [Pathname] sandbox_root
        #         The path retrieved from Sandbox#root.
        #
        def self.add_library_build_settings(library_path, xcconfig, sandbox_root)
          name = File.basename(library_path, '.a').sub(/\Alib/, '')
          dirname = '$(PODS_ROOT)/' + library_path.dirname.relative_path_from(sandbox_root).to_s
          build_settings = {
            'OTHER_LDFLAGS' => "-l#{name}",
            'LIBRARY_SEARCH_PATHS' => quote([dirname]),
          }
          xcconfig.merge!(build_settings)
        end

        # Add the code signing settings for generated targets to ensure that
        # frameworks are correctly signed to be integrated and re-signed when
        # building the application and embedding the framework
        #
        # @param  [Target] target
        #         The target.
        #
        # @param  [Xcodeproj::Config] xcconfig
        #         The xcconfig to edit.
        #
        def self.add_code_signing_settings(target, xcconfig)
          build_settings = {}
          if target.platform.to_sym == :osx
            build_settings['CODE_SIGN_IDENTITY'] = ''
          end
          xcconfig.merge!(build_settings)
        end

        # Checks if the given target requires specific settings and configures
        # the given Xcconfig.
        #
        # @param  [Target] target
        #         The target.
        #
        # @param  [Xcodeproj::Config] xcconfig
        #         The xcconfig to edit.
        #
        def self.add_target_specific_settings(target, xcconfig)
          if target.requires_frameworks?
            add_code_signing_settings(target, xcconfig)
          end
          add_language_specific_settings(target, xcconfig)
        end

        # Checks if the given target requires language specific settings and
        # configures the given Xcconfig.
        #
        # @param  [Target] target
        #         The target.
        #
        # @param  [Xcodeproj::Config] xcconfig
        #         The xcconfig to edit.
        #
        def self.add_language_specific_settings(target, xcconfig)
          if target.uses_swift?
            build_settings = {
              'OTHER_SWIFT_FLAGS' => '$(inherited) ' + quote(%w(-D COCOAPODS)),
            }
            xcconfig.merge!(build_settings)
          end
        end

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
        def self.add_developers_frameworks_if_needed(xcconfig, platform)
          matched_frameworks = xcconfig.frameworks & %w(XCTest SenTestingKit)
          unless matched_frameworks.empty?
            search_paths = xcconfig.attributes['FRAMEWORK_SEARCH_PATHS'] ||= ''
            search_paths_to_add = []
            search_paths_to_add << '$(inherited)'
            if platform == :ios || platform == :watchos
              search_paths_to_add << '"$(SDKROOT)/Developer/Library/Frameworks"'
            else
              search_paths_to_add << '"$(DEVELOPER_LIBRARY_DIR)/Frameworks"'
            end
            frameworks_path = '"$(PLATFORM_DIR)/Developer/Library/Frameworks"'
            search_paths_to_add << frameworks_path
            search_paths_to_add.each do |search_path|
              unless search_paths.include?(search_path)
                search_paths << ' ' unless search_paths.empty?
                search_paths << search_path
              end
            end
            search_paths
          end
        end

        #---------------------------------------------------------------------#
      end
    end
  end
end
