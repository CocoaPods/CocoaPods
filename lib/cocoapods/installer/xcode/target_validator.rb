module Pod
  class Installer
    class Xcode
      # The {Xcode::TargetValidator} ensures that the pod and aggregate target
      # configuration is valid for installation.
      #
      class TargetValidator
        # @return [Array<AggregateTarget>] The aggregate targets that should be
        #                                  validated.
        #
        attr_reader :aggregate_targets

        # @return [Array<PodTarget>] The pod targets that should be validated.
        #
        attr_reader :pod_targets

        # Create a new TargetValidator with aggregate and pod targets to
        # validate.
        #
        # @param [Array<AggregateTarget>] aggregate_targets
        #                                 The aggregate targets to validate.
        #
        # @param [Array<PodTarget>] pod_targets
        #                           The pod targets to validate.
        #
        def initialize(aggregate_targets, pod_targets)
          @aggregate_targets = aggregate_targets
          @pod_targets = pod_targets
        end

        # Perform the validation steps for the provided aggregate and pod
        # targets.
        #
        def validate!
          verify_no_duplicate_framework_and_library_names
          verify_no_static_framework_transitive_dependencies
          verify_no_pods_used_with_multiple_swift_versions
          verify_swift_pods_have_module_dependencies
        end

        private

        def verify_no_duplicate_framework_and_library_names
          aggregate_targets.each do |aggregate_target|
            aggregate_target.user_build_configurations.keys.each do |config|
              pod_targets = aggregate_target.pod_targets_for_build_configuration(config)
              file_accessors = pod_targets.flat_map(&:file_accessors)

              frameworks = file_accessors.flat_map(&:vendored_frameworks).uniq.map(&:basename)
              frameworks += pod_targets.select { |pt| pt.should_build? && pt.requires_frameworks? }.map(&:product_module_name).uniq
              verify_no_duplicate_names(frameworks, aggregate_target.label, 'frameworks')

              libraries = file_accessors.flat_map(&:vendored_libraries).uniq.map(&:basename)
              libraries += pod_targets.select { |pt| pt.should_build? && !pt.requires_frameworks? }.map(&:product_name)
              verify_no_duplicate_names(libraries, aggregate_target.label, 'libraries')
            end
          end
        end

        def verify_no_duplicate_names(names, label, type)
          duplicates = names.map { |n| n.to_s.downcase }.group_by { |f| f }.select { |_, v| v.size > 1 }.keys

          unless duplicates.empty?
            raise Informative, "The '#{label}' target has " \
              "#{type} with conflicting names: #{duplicates.to_sentence}."
          end
        end

        def verify_no_static_framework_transitive_dependencies
          aggregate_targets.each do |aggregate_target|
            next unless aggregate_target.requires_frameworks?

            aggregate_target.user_build_configurations.keys.each do |config|
              dynamic_pod_targets = aggregate_target.pod_targets_for_build_configuration(config).reject(&:static_framework?)

              dependencies = dynamic_pod_targets.select(&:should_build?).flat_map(&:dependencies)
              depended_upon_targets = dynamic_pod_targets.select { |t| dependencies.include?(t.pod_name) && !t.should_build? }

              static_libs = depended_upon_targets.flat_map(&:file_accessors).flat_map(&:vendored_static_artifacts)
              unless static_libs.empty?
                raise Informative, "The '#{aggregate_target.label}' target has " \
                  "transitive dependencies that include static binaries: (#{static_libs.to_sentence})"
              end

              static_framework_deps = dynamic_pod_targets.select(&:should_build?).flat_map(&:recursive_dependent_targets).select(&:static_framework?)
              unless static_framework_deps.empty?
                raise Informative, "The '#{aggregate_target.label}' target has " \
                  "transitive dependencies that include static frameworks: (#{static_framework_deps.flat_map(&:name).to_sentence})"
              end
            end
          end
        end

        def verify_no_pods_used_with_multiple_swift_versions
          error_message_for_target = lambda do |target|
            "#{target.name} (Swift #{target.swift_version})"
          end
          swift_pod_targets = pod_targets.select(&:uses_swift?)
          error_messages = swift_pod_targets.map do |pod_target|
            next unless pod_target.spec_swift_version.nil?
            swift_target_definitions = pod_target.target_definitions.reject { |target| target.swift_version.blank? }
            next if swift_target_definitions.empty? || swift_target_definitions.uniq(&:swift_version).count == 1
            target_errors = swift_target_definitions.map(&error_message_for_target).join(', ')
            "- #{pod_target.name} required by #{target_errors}"
          end.compact

          unless error_messages.empty?
            raise Informative, 'The following pods are integrated into targets ' \
              "that do not have the same Swift version:\n\n#{error_messages.join("\n")}"
          end
        end

        def verify_swift_pods_have_module_dependencies
          error_messages = []
          pod_targets.each do |pod_target|
            next unless pod_target.uses_swift?

            non_module_dependencies = []
            pod_target.dependent_targets.each do |dependent_target|
              next if !dependent_target.should_build? || dependent_target.defines_module?
              non_module_dependencies << dependent_target.name
            end

            next if non_module_dependencies.empty?

            error_messages << "The Swift pod `#{pod_target.name}` depends upon #{non_module_dependencies.map { |d| "`#{d}`" }.to_sentence}, " \
                              'which do not define modules. ' \
                              'To opt into those targets generating module maps '\
                              '(which is necessary to import them from Swift when building as static libraries), ' \
                              'you may set `use_modular_headers!` globally in your Podfile, '\
                              'or specify `:modular_headers => true` for particular dependencies.'
          end
          return if error_messages.empty?

          raise Informative, 'The following Swift pods cannot yet be integrated '\
                             "as static libraries:\n\n#{error_messages.join("\n\n")}"
        end
      end
    end
  end
end
