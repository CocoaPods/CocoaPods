module Pod
  module Generator
    module XCConfig
      # Generates the xcconfigs for the aggregate targets.
      #
      class AggregateXCConfig
        # @return [AggregateTarget] the target represented by this xcconfig.
        #
        attr_reader :target

        # @return [String] the name of the build configuration to generate this
        #         xcconfig for.
        #
        attr_reader :configuration_name

        # Initialize a new instance
        #
        # @param  [Target] target @see target
        #
        # @param  [String] configuration_name @see configuration_name
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
        #         the path where the xcconfig should be stored.
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
          includes_static_libs = !target.requires_frameworks?
          includes_static_libs ||= pod_targets.flat_map(&:file_accessors).any? { |fa| !fa.vendored_static_artifacts.empty? }
          config = {
            'FRAMEWORK_SEARCH_PATHS' => '$(inherited) ',
            'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) COCOAPODS=1',
            'HEADER_SEARCH_PATHS' => '$(inherited) ',
            'LIBRARY_SEARCH_PATHS' => '$(inherited) ',
            'OTHER_CFLAGS' => '$(inherited) ',
            'OTHER_LDFLAGS' => '$(inherited) ' + XCConfigHelper.default_ld_flags(target, includes_static_libs),
            'OTHER_SWIFT_FLAGS' => '$(inherited) ',
            'PODS_PODFILE_DIR_PATH' => target.podfile_dir_relative_path,
            'PODS_ROOT' => target.relative_pods_root,
            'SWIFT_INCLUDE_PATHS' => '$(inherited) ',
          }.merge(embedded_content_settings)

          @xcconfig = Xcodeproj::Config.new(config)

          @xcconfig.merge!(merged_user_target_xcconfigs)

          generate_settings_to_import_pod_targets

          XCConfigHelper.add_target_specific_settings(target, @xcconfig)

          targets = pod_targets + target.search_paths_aggregate_targets.flat_map(&:pod_targets)
          XCConfigHelper.generate_vendored_build_settings(target, targets, @xcconfig)
          XCConfigHelper.generate_other_ld_flags(target, pod_targets, @xcconfig)

          # TODO: Need to decide how we are going to ensure settings like these
          # are always excluded from the user's project.
          #
          # See https://github.com/CocoaPods/CocoaPods/issues/1216
          @xcconfig.attributes.delete('USE_HEADERMAP')

          # If any of the aggregate target dependencies bring in any vendored dynamic artifacts we should ensure to
          # update the runpath search paths.
          vendored_dynamic_artifacts = pod_targets.flat_map(&:file_accessors).flat_map(&:vendored_dynamic_artifacts)

          symbol_type = target.user_targets.map(&:symbol_type).uniq.first
          test_bundle = symbol_type == :octest_bundle || symbol_type == :unit_test_bundle || symbol_type == :ui_test_bundle
          XCConfigHelper.generate_ld_runpath_search_paths(target, target.requires_host_target?, test_bundle, @xcconfig) if target.requires_frameworks? || vendored_dynamic_artifacts.count > 0

          @xcconfig
        end

        #---------------------------------------------------------------------#

        protected

        # @return String the SWIFT_VERSION of the target being integrated
        #
        def target_swift_version
          target.target_definition.swift_version unless target.target_definition.swift_version.blank?
        end

        EMBED_STANDARD_LIBRARIES_MINIMUM_VERSION = Version.new('2.3')

        # @return [Hash<String, String>] the build settings necessary for Swift
        #  targets to be correctly embedded in their host.
        #
        def embedded_content_settings
          # For embedded targets, which live in a host target, CocoaPods
          # copies all of the embedded target's pod_targets its host
          # target. Therefore, this check will properly require the Swift
          # libs in the host target, if the embedded target has any pod targets
          # that use Swift. Setting this for the embedded target would
          # cause an App Store rejection because frameworks cannot be embedded
          # in embedded targets.

          swift_version = Version.new(target_swift_version)
          should_embed = !target.requires_host_target? && pod_targets.any?(&:uses_swift?)
          config = {}
          if should_embed
            if swift_version >= EMBED_STANDARD_LIBRARIES_MINIMUM_VERSION
              config['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'YES'
            else
              config['EMBEDDED_CONTENT_CONTAINS_SWIFT'] = 'YES'
            end
          end
          config
        end

        # @return [Hash<String, String>] the build settings necessary to import
        #         the pod targets.
        #
        def settings_to_import_pod_targets
          if target.requires_frameworks?
            build_pod_targets = pod_targets.select(&:should_build?)
            framework_header_search_paths = build_pod_targets.map do |target|
              "#{target.build_product_path}/Headers"
            end
            build_settings = {
              # TODO: remove quote imports in CocoaPods 2.0
              # Make framework headers discoverable by `import "…"`
              'OTHER_CFLAGS' => XCConfigHelper.quote(framework_header_search_paths, '-iquote'),
            }
            if pod_targets.any? { |t| !t.should_build? }
              # Make library headers discoverable by `#import "…"`
              library_header_search_paths = target.sandbox.public_headers.search_paths(target.platform)
              # TODO: remove quote imports in CocoaPods 2.0
              build_settings['HEADER_SEARCH_PATHS'] = XCConfigHelper.quote(library_header_search_paths)
              build_settings['OTHER_CFLAGS'] += ' ' + XCConfigHelper.quote(library_header_search_paths, '-isystem')
            end
            build_settings
          else
            # Make headers discoverable from $PODS_ROOT/Headers directory
            header_search_paths = target.sandbox.public_headers.search_paths(target.platform)
            {
              # TODO: remove quote imports in CocoaPods 2.0
              # by `#import "…"`
              'HEADER_SEARCH_PATHS' => XCConfigHelper.quote(header_search_paths),
              # by `#import <…>`
              'OTHER_CFLAGS' => XCConfigHelper.quote(header_search_paths, '-isystem'),
            }
          end
        end

        private

        # Add build settings, which ensure that the pod targets can be imported from the integrating target.
        # For >= 1.5.0 we use modular (stricter) header search paths this means that the integrated target will only be
        # able to import public headers using `<>` or `@import` notation, but never import any private headers.
        #
        # For < 1.5.0 legacy header search paths the same rules apply: It's the wild west.
        #
        def generate_settings_to_import_pod_targets
          @xcconfig.merge! XCConfigHelper.search_paths_for_dependent_targets(target, pod_targets)
          @xcconfig.merge!(settings_to_import_pod_targets)
          target.search_paths_aggregate_targets.each do |search_paths_target|
            generator = AggregateXCConfig.new(search_paths_target, configuration_name)
            @xcconfig.merge! XCConfigHelper.search_paths_for_dependent_targets(nil, search_paths_target.pod_targets)
            @xcconfig.merge!(generator.settings_to_import_pod_targets)
            # Propagate any HEADER_SEARCH_PATHS settings from the search paths.
            XCConfigHelper.propagate_header_search_paths_from_search_paths(search_paths_target, @xcconfig)
          end
        end

        private

        #---------------------------------------------------------------------#

        # !@group Private Helpers

        # Returns the {PodTarget}s which are active for the current
        # configuration name.
        #
        # @return [Array<PodTarget>]
        #
        def pod_targets
          target.pod_targets_for_build_configuration(configuration_name)
        end

        # Returns the +user_target_xcconfig+ for all pod targets and their spec
        # consumers grouped by keys
        #
        # @return [Hash{String,Hash{Target,String}]
        #
        def user_target_xcconfig_values_by_consumer_by_key
          pod_targets.each_with_object({}) do |target, hash|
            target.spec_consumers.each do |spec_consumer|
              spec_consumer.user_target_xcconfig.each do |k, v|
                (hash[k] ||= {})[spec_consumer] = v
              end
            end
          end
        end

        # Merges the +user_target_xcconfig+ for all pod targets into the
        # #xcconfig and warns on conflicting definitions.
        #
        # @return [Hash{String, String}]
        #
        def merged_user_target_xcconfigs
          settings = user_target_xcconfig_values_by_consumer_by_key
          settings.each_with_object({}) do |(key, values_by_consumer), xcconfig|
            uniq_values = values_by_consumer.values.uniq
            values_are_bools = uniq_values.all? { |v| v =~ /^(yes|no)$/i }
            if values_are_bools
              # Boolean build settings
              if uniq_values.count > 1
                UI.warn 'Can\'t merge user_target_xcconfig for pod targets: ' \
                  "#{values_by_consumer.keys.map(&:name)}. Boolean build "\
                  "setting #{key} has different values."
              else
                xcconfig[key] = uniq_values.first
              end
            elsif key =~ /S$/
              # Plural build settings
              xcconfig[key] = uniq_values.join(' ')
            else
              # Singular build settings
              if uniq_values.count > 1
                UI.warn 'Can\'t merge user_target_xcconfig for pod targets: ' \
                  "#{values_by_consumer.keys.map(&:name)}. Singular build "\
                  "setting #{key} has different values."
              else
                xcconfig[key] = uniq_values.first
              end
            end
          end
        end

        #---------------------------------------------------------------------#
      end
    end
  end
end
