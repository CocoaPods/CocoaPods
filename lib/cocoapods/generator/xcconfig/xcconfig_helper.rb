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
        BUILD_DIR_VARIABLE = '${PODS_BUILD_DIR}'.freeze

        # @return [String] Used as alias for CONFIGURATION_BUILD_DIR, so that
        #         when this is overridden per {PodTarget}, it is still possible
        #         to reference other build products relative to the original
        #         path. Furthermore if it was overridden in the user target,
        #         the user can override this variable to point to the standard
        #         directory, which will be used by CocoaPods.
        #
        CONFIGURATION_BUILD_DIR_VARIABLE = '${PODS_CONFIGURATION_BUILD_DIR}'.freeze

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
        # @param  [Boolean] include_objc_flag
        #         whether to include `-ObjC` in the other linker flags
        #
        # @return [String] the default linker flags. `-ObjC` is optionally included depending
        #         on the target while `-fobjc-arc` is included only if requested in the Podfile.
        #
        def self.default_ld_flags(target, include_objc_flag = false)
          ld_flags = ''
          ld_flags << '-ObjC' if include_objc_flag
          if target.podfile.set_arc_compatibility_flag? &&
              target.spec_consumers.any?(&:requires_arc?)
            ld_flags << ' -fobjc-arc'
          end
          ld_flags.strip
        end

        # Configures the given Xcconfig
        #
        # @param  [Target] target
        #         The root target, may be nil.
        #
        # @param  [PodTarget] pod_target
        #         The pod target, which holds the list of +Spec::FileAccessor+.
        #
        # @param  [Xcodeproj::Config] xcconfig
        #         The xcconfig to edit.
        #
        # @param  [Boolean] include_ld_flags
        #         Indicates whether or not to generate ld flags in addition to compile flags
        #
        # @param  [Boolean] test_xcconfig
        #         Whether the settings for dependent targets are being generated for a test xcconfig or not.
        #
        # @return [void]
        #
        def self.add_settings_for_file_accessors_of_target(target, pod_target, xcconfig, include_ld_flags = true, test_xcconfig = false)
          file_accessors = pod_target.file_accessors
          file_accessors = file_accessors.reject { |f| f.spec.test_specification? } unless test_xcconfig
          file_accessors.each do |file_accessor|
            if target.nil? || !file_accessor.spec.test_specification?
              XCConfigHelper.add_spec_build_settings_to_xcconfig(file_accessor.spec_consumer, xcconfig) if include_ld_flags
              XCConfigHelper.add_static_dependency_build_settings(target, pod_target, xcconfig, file_accessor, include_ld_flags)
            end
          end
          XCConfigHelper.add_dynamic_dependency_build_settings(target, pod_target, xcconfig, include_ld_flags, test_xcconfig)
          if pod_target.requires_frameworks?
            pod_target.dependent_targets.each do |dependent_target|
              XCConfigHelper.add_dynamic_dependency_build_settings(target, dependent_target, xcconfig, include_ld_flags, test_xcconfig)
            end
          end
        end

        # Adds build settings for static vendored frameworks and libraries.
        #
        # @param  [Target] target
        #         The root target, may be nil.
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
        # @param  [Boolean] include_ld_flags
        #         Indicates whether or not to generate ld flags in addition to compile flags
        #
        # @return [void]
        #
        def self.add_static_dependency_build_settings(target, pod_target, xcconfig, file_accessor, include_ld_flags)
          if target.nil? || !file_accessor.spec.test_specification?
            adds_other_ldflags = include_ld_flags && XCConfigHelper.links_dependency?(target, pod_target)
            file_accessor.vendored_static_frameworks.each do |vendored_static_framework|
              XCConfigHelper.add_framework_build_settings(vendored_static_framework, xcconfig, pod_target.sandbox.root, adds_other_ldflags)
            end
            file_accessor.vendored_static_libraries.each do |vendored_static_library|
              XCConfigHelper.add_library_build_settings(vendored_static_library, xcconfig, pod_target.sandbox.root, adds_other_ldflags)
            end
          end
        end

        # @param  [AggregateTarget] aggregate_target
        #         The aggregate target, may be nil.
        #
        # @param  [PodTarget] pod_target
        #         The pod target to link or not.
        #
        # @return [Boolean] Whether static dependency should be added to the 'OTHER_LDFLAGS'
        #         of the aggregate target. Aggregate targets that inherit search paths will only link
        #         if the target has explicitly declared the pod dependency.
        #
        def self.links_dependency?(aggregate_target, pod_target)
          return true if aggregate_target.nil? || aggregate_target.target_definition.inheritance == 'complete'
          aggregate_target.pod_targets_to_link.include?(pod_target)
        end

        # Adds build settings for dynamic vendored frameworks and libraries.
        #
        # @param  [Target] target
        #         The root target, may be nil.
        #
        # @param [PodTarget] pod_target
        #        The pod target, which holds the list of +Spec::FileAccessor+.
        #
        # @param [Xcodeproj::Config] xcconfig
        #        The xcconfig to edit.
        #
        # @param  [Boolean] include_ld_flags
        #         Indicates whether or not to generate ld flags in addition to compile flags
        #
        # @param  [Boolean] test_xcconfig
        #         Whether the settings for dependent targets are being generated for a test xcconfig or not.
        #
        # @return [void]
        #
        def self.add_dynamic_dependency_build_settings(target, pod_target, xcconfig, include_ld_flags, test_xcconfig)
          file_accessors = pod_target.file_accessors
          file_accessors = file_accessors.reject { |f| f.spec.test_specification? } unless test_xcconfig
          file_accessors.each do |file_accessor|
            if target.nil? || !file_accessor.spec.test_specification?
              file_accessor.vendored_dynamic_frameworks.each do |vendored_dynamic_framework|
                XCConfigHelper.add_framework_build_settings(vendored_dynamic_framework, xcconfig, pod_target.sandbox.root, include_ld_flags)
              end
              file_accessor.vendored_dynamic_libraries.each do |vendored_dynamic_library|
                XCConfigHelper.add_library_build_settings(vendored_dynamic_library, xcconfig, pod_target.sandbox.root, include_ld_flags)
              end
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
        # @param  [Boolean] include_ld_flags
        #         Indicates whether or not to generate ld flags in addition to compile flags
        #
        # @return [void]
        #
        def self.add_framework_build_settings(framework_path, xcconfig, sandbox_root, include_ld_flags = true)
          name = File.basename(framework_path, '.framework')
          dirname = '${PODS_ROOT}/' + framework_path.dirname.relative_path_from(sandbox_root).to_s
          build_settings = {
            'FRAMEWORK_SEARCH_PATHS' => quote([dirname]),
          }
          build_settings['OTHER_LDFLAGS'] = "-framework \"#{name}\"" if include_ld_flags
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
        # @param  [Boolean] include_ld_flags
        #         Indicates whether or not to generate ld flags in addition to compile flags
        #
        # @return [void]
        #
        def self.add_library_build_settings(library_path, xcconfig, sandbox_root, include_ld_flags = true)
          extension = File.extname(library_path)
          name = File.basename(library_path, extension).sub(/\Alib/, '')
          dirname = '${PODS_ROOT}/' + library_path.dirname.relative_path_from(sandbox_root).to_s
          build_settings = {
            'LIBRARY_SEARCH_PATHS' => quote([dirname]),
          }
          build_settings['OTHER_LDFLAGS'] = "-l\"#{name}\"" if include_ld_flags
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
        # @param  [Boolean] test_xcconfig
        #         Whether the settings for dependent targets are being generated for a test xcconfig or not.
        #
        # @return [Hash<String, String>] the settings
        #
        def self.search_paths_for_dependent_targets(target, dependent_targets, test_xcconfig = false)
          dependent_targets = dependent_targets.select(&:should_build?)

          # Filter out dependent targets that are subsets of another target.
          subset_targets = []
          dependent_targets.uniq.combination(2) do |a, b|
            if (a.specs - b.specs).empty?
              subset_targets << a
            elsif (b.specs - a.specs).empty?
              subset_targets << b
            end
          end
          dependent_targets -= subset_targets

          # Alias build dirs to avoid recursive definitions for pod targets and depending
          # on build settings which could be overwritten in the user target.
          build_settings = {
            BUILD_DIR_VARIABLE[2..-2] => '${BUILD_DIR}',
            CONFIGURATION_BUILD_DIR_VARIABLE[2..-2] => "#{BUILD_DIR_VARIABLE}/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)",
          }

          # Scope pod targets as long as they are not test targets.
          if !test_xcconfig && target.respond_to?(:configuration_build_dir)
            build_settings['CONFIGURATION_BUILD_DIR'] = target.configuration_build_dir(CONFIGURATION_BUILD_DIR_VARIABLE)
          end

          module_map_files = []
          unless dependent_targets.empty?
            framework_search_paths = []
            library_search_paths = []
            swift_import_paths = []
            dependent_targets.each do |dependent_target|
              if dependent_target.requires_frameworks?
                framework_search_paths << dependent_target.configuration_build_dir(CONFIGURATION_BUILD_DIR_VARIABLE)
              else
                library_search_paths << dependent_target.configuration_build_dir(CONFIGURATION_BUILD_DIR_VARIABLE)
                if dependent_target.defines_module?
                  module_map_file = if dependent_target.uses_swift?
                                      # for swift, we have a custom build phase that copies in the module map, appending the .Swift module
                                      "${PODS_CONFIGURATION_BUILD_DIR}/#{dependent_target.label}/#{dependent_target.product_module_name}.modulemap"
                                    else
                                      "${PODS_ROOT}/#{dependent_target.module_map_path.relative_path_from(dependent_target.sandbox.root)}"
                                    end
                  module_map_files << %(-fmodule-map-file="#{module_map_file}")
                  swift_import_paths << dependent_target.configuration_build_dir(CONFIGURATION_BUILD_DIR_VARIABLE) if dependent_target.uses_swift?
                end
              end
            end

            build_settings['FRAMEWORK_SEARCH_PATHS'] = XCConfigHelper.quote(framework_search_paths.uniq)
            build_settings['LIBRARY_SEARCH_PATHS']   = XCConfigHelper.quote(library_search_paths.uniq)
            build_settings['SWIFT_INCLUDE_PATHS']    = XCConfigHelper.quote(swift_import_paths.uniq)
          end

          other_swift_flags = module_map_files.tap(&:uniq!).flat_map { |f| ['-Xcc', f] }
          if target.is_a?(PodTarget) && !target.requires_frameworks? && target.defines_module? && !test_xcconfig
            # make it possible for a mixed swift/objc static library to be able to import the objc from within swift
            other_swift_flags += ['-import-underlying-module', '-Xcc', '-fmodule-map-file="${SRCROOT}/${MODULEMAP_FILE}"']
          end
          # unconditionally set these, because of (the possibility of) having to add the pod targets own module map file
          build_settings['OTHER_CFLAGS']           = module_map_files.join(' ')
          build_settings['OTHER_SWIFT_FLAGS']      = other_swift_flags.join(' ')

          build_settings
        end

        # Updates xcconfig with the HEADER_SEARCH_PATHS from the search_paths.
        #
        # @param  [Target] search_paths_target
        #         The target.
        #
        # @param  [Xcodeproj::Config] xcconfig
        #         The xcconfig to edit.
        #
        def self.propagate_header_search_paths_from_search_paths(search_paths_target, xcconfig)
          header_search_paths_list = []
          search_paths_target.pod_targets.each do |target|
            target.spec_consumers.each do |spec_consumer|
              paths = spec_consumer.user_target_xcconfig['HEADER_SEARCH_PATHS']
              header_search_paths_list <<= paths unless paths.nil?
            end
            unless header_search_paths_list == []
              header_search_paths = header_search_paths_list.join(' ')
              unless header_search_paths.include? '$(inherited)'
                header_search_paths = '$(inherited) ' + header_search_paths
              end
              build_settings = { 'HEADER_SEARCH_PATHS' => header_search_paths }
              xcconfig.merge!(build_settings)
            end
          end
        end

        # Add custom build settings and required build settings to link to
        # vendored libraries and frameworks.
        #
        # @param  [Target] target
        #         The root target, may be nil.
        #
        # @param  [Array<PodTarget] dep_targets
        #         The dependency targets to add the vendored build settings for.
        #
        # @param  [Xcodeproj::Config] xcconfig
        #         The xcconfig to edit.
        #
        # @param  [Boolean] include_ld_flags
        #         Indicates whether or not to generate ld flags in addition to compile flags
        #
        # @param  [Boolean] test_xcconfig
        #         Indicates whether or not the generated ld flags are for a test xcconfig or not
        #
        # @note
        #   In case of generated pod targets, which require frameworks, the
        #   vendored frameworks and libraries are already linked statically
        #   into the framework binary and must not be linked again to the
        #   user target.
        #
        def self.generate_vendored_build_settings(target, dep_targets, xcconfig, include_ld_flags = true, test_xcconfig = false)
          dep_targets.each do |dep_target|
            unless dep_target.should_build? && dep_target.requires_frameworks? && !dep_target.static_framework?
              XCConfigHelper.add_settings_for_file_accessors_of_target(target, dep_target, xcconfig, include_ld_flags, test_xcconfig)
            end
          end
        end

        # Ensure to add the default linker run path search paths as they could
        # be not present due to being historically absent in the project or
        # target template or just being removed by being superficial when
        # linking third-party dependencies exclusively statically. This is not
        # something a project needs specifically for the integration with
        # CocoaPods, but makes sure that it is self-contained for the given
        # constraints.
        #
        # @param [Target] target
        #        The target, this can be an aggregate target or a pod target.
        #
        # @param [Boolean] requires_host_target
        #        If this target requires a host target
        #
        # @param [Boolean] test_bundle
        #        Whether this is a test bundle or not. This has an effect when the platform is `osx` and changes
        #        the runtime search paths accordingly.
        #
        # @param [Xcodeproj::Config] xcconfig
        #        The xcconfig to edit.
        #
        # @return [void]
        #
        def self.generate_ld_runpath_search_paths(target, requires_host_target, test_bundle, xcconfig)
          ld_runpath_search_paths = ['$(inherited)']
          if target.platform.symbolic_name == :osx
            ld_runpath_search_paths << "'@executable_path/../Frameworks'"
            ld_runpath_search_paths << \
              if test_bundle
                "'@loader_path/../Frameworks'"
              else
                "'@loader_path/Frameworks'"
              end
          else
            ld_runpath_search_paths << [
              "'@executable_path/Frameworks'",
              "'@loader_path/Frameworks'",
            ]
            ld_runpath_search_paths << "'@executable_path/../../Frameworks'" if requires_host_target
          end
          xcconfig.merge!('LD_RUNPATH_SEARCH_PATHS' => ld_runpath_search_paths.join(' '))
        end

        # Add pod target to list of frameworks / libraries that are linked
        # with the user’s project.
        #
        # @param  [AggregateTarget] aggregate_target
        #         The aggregate target, may be nil.
        #
        # @param  [Array<PodTarget] pod_targets
        #         The pod targets to add the vendored build settings for.
        #
        # @param  [Xcodeproj::Config] xcconfig
        #         The xcconfig to edit.
        #
        # @return [void]
        #
        def self.generate_other_ld_flags(aggregate_target, pod_targets, xcconfig)
          # Make sure -framework option gets added for the search paths when static_frameworks are involved.
          # Otherwise test targets won't link in their primary target's dependencies.
          unless aggregate_target.nil?
            dependent_targets = aggregate_target.search_paths_aggregate_targets
            dependent_targets.each do |dependent_target|
              if aggregate_target.requires_frameworks? && dependent_target.pod_targets.any?(&:static_framework?)
                generate_other_ld_flags(dependent_target, dependent_target.pod_targets, xcconfig)
              end
            end
          end
          other_ld_flags = pod_targets.select(&:should_build?).map do |pod_target|
            if pod_target.requires_frameworks?
              %(-framework "#{pod_target.product_basename}")
            elsif XCConfigHelper.links_dependency?(aggregate_target, pod_target)
              %(-l "#{pod_target.product_basename}")
            end
          end
          xcconfig.merge!('OTHER_LDFLAGS' => other_ld_flags.compact.join(' '))
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
