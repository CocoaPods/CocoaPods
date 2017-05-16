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
          verify_framework_usage
        end

        private

        def verify_no_duplicate_framework_and_library_names
          aggregate_targets.each do |aggregate_target|
            aggregate_target.user_build_configurations.keys.each do |config|
              pod_targets = aggregate_target.pod_targets_for_build_configuration(config)
              file_accessors = pod_targets.flat_map(&:file_accessors)

              frameworks = file_accessors.flat_map(&:vendored_frameworks).uniq.map(&:basename)
              frameworks += pod_targets.select { |pt| pt.should_build? && pt.requires_frameworks? }.map(&:product_module_name)
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
              pod_targets = aggregate_target.pod_targets_for_build_configuration(config)

              dependencies = pod_targets.select(&:should_build?).flat_map(&:dependencies)
              dependended_upon_targets = pod_targets.select { |t| dependencies.include?(t.pod_name) && !t.should_build? }

              static_libs = dependended_upon_targets.flat_map(&:file_accessors).flat_map(&:vendored_static_artifacts)
              unless static_libs.empty?
                raise Informative, "The '#{aggregate_target.label}' target has " \
                  "transitive dependencies that include static binaries: (#{static_libs.to_sentence})"
              end
            end
          end
        end

        def verify_framework_usage
          aggregate_targets.each do |aggregate_target|
            next if aggregate_target.requires_frameworks?

            aggregate_target.user_build_configurations.keys.each do |config|
              pod_targets = aggregate_target.pod_targets_for_build_configuration(config)

              swift_pods = pod_targets.select(&:uses_swift?)
              unless swift_pods.empty?
                raise Informative, 'Pods written in Swift can only be integrated as frameworks; ' \
                  'add `use_frameworks!` to your Podfile or target to opt into using it. ' \
                  "The Swift #{swift_pods.size == 1 ? 'Pod being used is' : 'Pods being used are'}: " +
                  swift_pods.map(&:name).to_sentence
              end
            end
          end
        end
      end
    end
  end
end
