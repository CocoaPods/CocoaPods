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
            'OTHER_LDFLAGS' => '$(inherited) ' + XCConfigHelper.default_ld_flags(target, includes_static_libs),
            'PODS_ROOT' => target.relative_pods_root,
            'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) COCOAPODS=1',
            'FRAMEWORK_SEARCH_PATHS' => '$(inherited) ',
            'LIBRARY_SEARCH_PATHS' => '$(inherited) ',
          }
          # For embedded targets, which live in a host target, CocoaPods
          # copies all of the embedded target's pod_targets its host
          # target. Therefore, this check will properly require the Swift
          # libs in the host target, if the embedded target has any pod targets
          # that use Swift. Setting this for the embedded target would
          # cause an App Store rejection because frameworks cannot be embedded
          # in embedded targets.
          if !target.requires_host_target? && pod_targets.any?(&:uses_swift?)
            config['EMBEDDED_CONTENT_CONTAINS_SWIFT'] = 'YES'
          end
          @xcconfig = Xcodeproj::Config.new(config)

          @xcconfig.merge!(merged_user_target_xcconfigs)

          generate_settings_to_import_pod_targets

          XCConfigHelper.add_target_specific_settings(target, @xcconfig)

          generate_vendored_build_settings
          generate_other_ld_flags

          # TODO: Need to decide how we are going to ensure settings like these
          # are always excluded from the user's project.
          #
          # See https://github.com/CocoaPods/CocoaPods/issues/1216
          @xcconfig.attributes.delete('USE_HEADERMAP')

          generate_ld_runpath_search_paths if target.requires_frameworks?

          @xcconfig
        end

        #---------------------------------------------------------------------#

        protected

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
              # Make framework headers discoverable by `import "…"`
              'OTHER_CFLAGS' => '$(inherited) ' + XCConfigHelper.quote(framework_header_search_paths, '-iquote'),
            }
            if pod_targets.any? { |t| !t.should_build? }
              # Make library headers discoverable by `#import "…"`
              library_header_search_paths = target.sandbox.public_headers.search_paths(target.platform)
              build_settings['HEADER_SEARCH_PATHS'] = '$(inherited) ' + XCConfigHelper.quote(library_header_search_paths)
              build_settings['OTHER_CFLAGS'] += ' ' + XCConfigHelper.quote(library_header_search_paths, '-isystem')
            end
            build_settings
          else
            # Make headers discoverable from $PODS_ROOT/Headers directory
            header_search_paths = target.sandbox.public_headers.search_paths(target.platform)
            {
              # by `#import "…"`
              'HEADER_SEARCH_PATHS' => '$(inherited) ' + XCConfigHelper.quote(header_search_paths),
              # by `#import <…>`
              'OTHER_CFLAGS' => '$(inherited) ' + XCConfigHelper.quote(header_search_paths, '-isystem'),
            }
          end
        end

        private

        # Add build settings, which ensure that the pod targets can be imported
        # from the integrating target by all sort of imports, which are:
        #  - `#import <…>`
        #  - `#import "…"`
        #  - `@import …;` / `import …`
        #
        def generate_settings_to_import_pod_targets
          @xcconfig.merge! XCConfigHelper.settings_for_dependent_targets(target, pod_targets)
          @xcconfig.merge!(settings_to_import_pod_targets)
          target.search_paths_aggregate_targets.each do |search_paths_target|
            generator = AggregateXCConfig.new(search_paths_target, configuration_name)
            @xcconfig.merge! XCConfigHelper.settings_for_dependent_targets(nil, search_paths_target.pod_targets)
            @xcconfig.merge!(generator.settings_to_import_pod_targets)
          end
        end

        # Add custom build settings and required build settings to link to
        # vendored libraries and frameworks.
        #
        # @note
        #   In case of generated pod targets, which require frameworks, the
        #   vendored frameworks and libraries are already linked statically
        #   into the framework binary and must not be linked again to the
        #   user target.
        #
        def generate_vendored_build_settings
          pod_targets.each do |pod_target|
            unless pod_target.should_build? && pod_target.requires_frameworks?
              XCConfigHelper.add_settings_for_file_accessors_of_target(pod_target, @xcconfig)
            end
          end
        end

        # Add pod target to list of frameworks / libraries that are linked
        # with the user’s project.
        #
        def generate_other_ld_flags
          other_ld_flags = pod_targets.select(&:should_build?).map do |pod_target|
            if pod_target.requires_frameworks?
              %(-framework "#{pod_target.product_basename}")
            else
              %(-l "#{pod_target.product_basename}")
            end
          end

          @xcconfig.merge!('OTHER_LDFLAGS' => other_ld_flags.join(' '))
        end

        # Ensure to add the default linker run path search paths as they could
        # be not present due to being historically absent in the project or
        # target template or just being removed by being superficial when
        # linking third-party dependencies exclusively statically. This is not
        # something a project needs specifically for the integration with
        # CocoaPods, but makes sure that it is self-contained for the given
        # constraints.
        #
        def generate_ld_runpath_search_paths
          ld_runpath_search_paths = ['$(inherited)']
          if target.platform.symbolic_name == :osx
            ld_runpath_search_paths << "'@executable_path/../Frameworks'"
            ld_runpath_search_paths << \
              if target.native_target.symbol_type == :unit_test_bundle
                "'@loader_path/../Frameworks'"
              else
                "'@loader_path/Frameworks'"
              end
          else
            ld_runpath_search_paths << [
              "'@executable_path/Frameworks'",
              "'@loader_path/Frameworks'",
            ]
          end
          @xcconfig.merge!('LD_RUNPATH_SEARCH_PATHS' => ld_runpath_search_paths.join(' '))
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
            values_are_bools = uniq_values.all? { |v| v =~ /(yes|no)/i }
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
