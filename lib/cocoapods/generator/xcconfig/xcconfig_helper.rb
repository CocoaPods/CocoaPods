require 'active_support/core_ext/object/try'

module Pod
  module Generator
    module XCConfig
      # Stores the shared logic of the classes of the XCConfig module.
      #
      module XCConfigHelper
        # @return [String] Used as alias for BUILD_DIR, so that when this
        #         is overridden in the user target, the user can override
        #         this variable to point to the standard directory, which
        #         will be used by CocoaPods.
        #
        BUILD_DIR_VARIABLE = '$PODS_BUILD_DIR'.freeze

        # @return [String] Used as alias for CONFIGURATION_BUILD_DIR, so that
        #         when this is overridden per {PodTarget}, it is still possible
        #         to reference other build products relative to the original
        #         path. Furthermore if it was overridden in the user target,
        #         the user can override this variable to point to the standard
        #         directory, which will be used by CocoaPods.
        #
        CONFIGURATION_BUILD_DIR_VARIABLE = '$PODS_CONFIGURATION_BUILD_DIR'.freeze

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
          strings.sort.map { |s| %W( #{prefix}"#{s}"          ) }.join(' ')
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
        # @param  [AggregateTarget] aggregate_target
        #         The aggregate target, may be nil.
        #
        # @param  [PodTarget] pod_target
        #         The pod target, which holds the list of +Spec::FileAccessor+.
        #
        # @param  [Xcodeproj::Config] xcconfig
        #         The xcconfig to edit.
        #
        # @return [void]
        #
        def self.add_settings_for_file_accessors_of_target(aggregate_target, pod_target, xcconfig)
          pod_target.file_accessors.each do |file_accessor|
            XCConfigHelper.add_spec_build_settings_to_xcconfig(file_accessor.spec_consumer, xcconfig)
            XCConfigHelper.add_static_dependency_build_settings(aggregate_target, pod_target, xcconfig, file_accessor)
          end
          XCConfigHelper.add_dynamic_dependency_build_settings(pod_target, xcconfig)
          if pod_target.requires_frameworks?
            pod_target.dependent_targets.each do |dependent_target|
              XCConfigHelper.add_dynamic_dependency_build_settings(dependent_target, xcconfig)
            end
          end
        end

        # Adds build settings for static vendored frameworks and libraries.
        #
        # @param  [AggregateTarget] aggregate_target
        #         The aggregate target, may be nil.
        #
        # @param [PodTarget] pod_target
        #        The pod target, which holds the list of +Spec::FileAccessor+.
        #
        # @param [Xcodeproj::Config] xcconfig
        #        The xcconfig to edit.
        #
        # @param [Spec::FileAccessor] file_accessor
        #        The file accessor, which holds the list of static frameworks.
        #
        # @return [void]
        #
        def self.add_static_dependency_build_settings(aggregate_target, pod_target, xcconfig, file_accessor)
          file_accessor.vendored_static_frameworks.each do |vendored_static_framework|
            if aggregate_target.nil? || aggregate_target.target_definition.inheritance != 'search_paths'
              XCConfigHelper.add_framework_build_settings(vendored_static_framework, xcconfig, pod_target.sandbox.root)
            end
          end
          file_accessor.vendored_static_libraries.each do |vendored_static_library|
            XCConfigHelper.add_library_build_settings(vendored_static_library, xcconfig, pod_target.sandbox.root)
          end
        end

        # Adds build settings for dynamic vendored frameworks and libraries.
        #
        # @param [PodTarget] pod_target
        #        The pod target, which holds the list of +Spec::FileAccessor+.
        #
        # @param [Xcodeproj::Config] xcconfig
        #        The xcconfig to edit.
        #
        # @return [void]
        #
        def self.add_dynamic_dependency_build_settings(pod_target, xcconfig)
          pod_target.file_accessors.each do |file_accessor|
            file_accessor.vendored_dynamic_frameworks.each do |vendored_dynamic_framework|
              XCConfigHelper.add_framework_build_settings(vendored_dynamic_framework, xcconfig, pod_target.sandbox.root)
            end
            file_accessor.vendored_dynamic_libraries.each do |vendored_dynamic_library|
              XCConfigHelper.add_library_build_settings(vendored_dynamic_library, xcconfig, pod_target.sandbox.root)
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
        # @return [void]
        #
        def self.add_spec_build_settings_to_xcconfig(consumer, xcconfig)
          xcconfig.libraries.merge(consumer.libraries)
          xcconfig.frameworks.merge(consumer.frameworks)
          xcconfig.weak_frameworks.merge(consumer.weak_frameworks)
          add_developers_frameworks_if_needed(xcconfig)
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
        # @return [void]
        #
        def self.add_framework_build_settings(framework_path, xcconfig, sandbox_root)
          name = File.basename(framework_path, '.framework')
          dirname = '${PODS_ROOT}/' + framework_path.dirname.relative_path_from(sandbox_root).to_s
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
        # @return [void]
        #
        def self.add_library_build_settings(library_path, xcconfig, sandbox_root)
          extension = File.extname(library_path)
          name = File.basename(library_path, extension).sub(/\Alib/, '')
          dirname = '${PODS_ROOT}/' + library_path.dirname.relative_path_from(sandbox_root).to_s
          build_settings = {
            'OTHER_LDFLAGS' => "-l#{name}",
            'LIBRARY_SEARCH_PATHS' => '$(inherited) ' + quote([dirname]),
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
        # @return [void]
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
        # @return [void]
        #
        def self.add_target_specific_settings(target, xcconfig)
          if target.requires_frameworks?
            add_code_signing_settings(target, xcconfig)
          end
          add_language_specific_settings(target, xcconfig)
        end

        # Returns the search paths for frameworks and libraries the given target
        # depends on, so that it can be correctly built and linked.
        #
        # @param  [Target] target
        #         The target.
        #
        # @param  [Array<PodTarget>] dependent_targets
        #         The pod targets the given target depends on.
        #
        # @return [Hash<String, String>] the settings
        #
        def self.settings_for_dependent_targets(target, dependent_targets)
          dependent_targets = dependent_targets.select(&:should_build?)

          # Alias build dirs to avoid recursive definitions for pod targets and depending
          # on build settings which could be overwritten in the user target.
          build_settings = {
            BUILD_DIR_VARIABLE[1..-1] => '$BUILD_DIR',
            CONFIGURATION_BUILD_DIR_VARIABLE[1..-1] => "#{BUILD_DIR_VARIABLE}/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)",
          }

          # Scope pod targets
          if target.respond_to?(:configuration_build_dir)
            build_settings['CONFIGURATION_BUILD_DIR'] = target.configuration_build_dir(CONFIGURATION_BUILD_DIR_VARIABLE)
          end

          unless dependent_targets.empty?
            framework_search_paths = []
            library_search_paths = []
            dependent_targets.each do |dependent_target|
              if dependent_target.requires_frameworks?
                framework_search_paths << dependent_target.configuration_build_dir(CONFIGURATION_BUILD_DIR_VARIABLE)
              else
                library_search_paths << dependent_target.configuration_build_dir(CONFIGURATION_BUILD_DIR_VARIABLE)
              end
            end
            build_settings['FRAMEWORK_SEARCH_PATHS'] = XCConfigHelper.quote(framework_search_paths.uniq)
            build_settings['LIBRARY_SEARCH_PATHS']   = XCConfigHelper.quote(library_search_paths.uniq)
          end
          build_settings
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
        # @return [void]
        #
        def self.add_language_specific_settings(target, xcconfig)
          if target.uses_swift?
            other_swift_flags = ['$(inherited)', quote(%w(-D COCOAPODS))]
            other_swift_flags << quote(%w(-suppress-warnings)) if target.try(:inhibit_warnings?)
            build_settings = { 'OTHER_SWIFT_FLAGS' => other_swift_flags.join(' ') }
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
        def self.add_developers_frameworks_if_needed(xcconfig)
          matched_frameworks = xcconfig.frameworks & %w(XCTest SenTestingKit)
          unless matched_frameworks.empty?
            search_paths = xcconfig.attributes['FRAMEWORK_SEARCH_PATHS'] ||= ''
            search_paths_to_add = []
            search_paths_to_add << '$(inherited)'
            frameworks_path = '"$(PLATFORM_DIR)/Developer/Library/Frameworks"'
            search_paths_to_add << frameworks_path
            search_paths_to_add.each do |search_path|
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
