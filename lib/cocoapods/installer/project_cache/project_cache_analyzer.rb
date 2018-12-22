module Pod
  class Installer
    module ProjectCache
      # Analyzes the project cache and computes which pod targets need to be generated.
      #
      class ProjectCacheAnalyzer
        require 'cocoapods/installer/project_cache/project_cache_analysis_result'

        # @return [Sandbox] Project sandbox.
        #
        attr_reader :sandbox

        # @return [ProjectInstallationCache] The cache of targets that were previously installed.
        #
        attr_reader :cache

        # @return [Hash{String => Symbol}] The hash of user build configurations.
        #
        attr_reader :build_configurations

        # @return [String] The object version from the user project.
        #
        attr_reader :project_object_version

        # @return [Array<PodTarget>] The list of pod targets.
        #
        attr_reader :pod_targets

        # @return [Array<AggregateTarget>] The list of aggregate targets.
        #
        attr_reader :aggregate_targets

        # @return [Bool] Flag indicating if we want to ignore the cache and force a clean installation.
        #
        attr_reader :clean_install

        # Initialize a new instance.
        #
        # @param [Sandbox] sandbox @see #sandbox
        # @param [ProjectInstallationCache] cache @see #cache
        # @param [Hash{String => Symbol}] build_configurations @see #build_configurations
        # @param [String] project_object_version @see #project_object_version
        # @param [Array<PodTarget>] pod_targets @see #pod_targets
        # @param [Array<AggregateTarget>] aggregate_targets @see #aggregate_targets
        # @param [Bool] clean_install @see #clean_install
        #
        def initialize(sandbox, cache, build_configurations, project_object_version, pod_targets, aggregate_targets,
                       clean_install: false)
          @sandbox = sandbox
          @cache = cache
          @build_configurations = build_configurations
          @pod_targets = pod_targets
          @aggregate_targets = aggregate_targets
          @project_object_version = project_object_version
          @clean_install = clean_install
        end

        # @return [ProjectCacheAnalysisResult]
        #         Compares all targets stored against the cache and computes which targets need to be regenerated.
        #
        def analyze
          target_by_label = Hash[(pod_targets + aggregate_targets).map { |target| [target.label, target] }]
          cache_key_by_target_label = Hash[target_by_label.map do |label, target|
            if target.is_a?(PodTarget)
              local = sandbox.local?(target.pod_name)
              checkout_options = sandbox.checkout_sources[target.pod_name]
              [label, TargetCacheKey.from_pod_target(target, :is_local_pod => local, :checkout_options => checkout_options)]
            elsif target.is_a?(AggregateTarget)
              [label, TargetCacheKey.from_aggregate_target(target)]
            else
              raise "[BUG] Unknown target type #{target}"
            end
          end]

          # Bail out early since these properties affect all targets and their associate projects.
          if cache.build_configurations != build_configurations || cache.project_object_version != project_object_version || clean_install
            return ProjectCacheAnalysisResult.new(pod_targets, aggregate_targets, cache_key_by_target_label,
                                                  build_configurations, project_object_version)
          end

          added_targets = (cache_key_by_target_label.keys - cache.cache_key_by_target_label.keys).map do |label|
            target_by_label[label]
          end
          added_pod_targets = added_targets.select { |target| target.is_a?(PodTarget) }
          added_aggregate_targets = added_targets.select { |target| target.is_a?(AggregateTarget) }

          changed_targets = []
          cache_key_by_target_label.each do |label, cache_key|
            next unless cache.cache_key_by_target_label[label]
            if cache_key.key_difference(cache.cache_key_by_target_label[label]) == :project
              changed_targets << target_by_label[label]
            end
          end

          changed_pod_targets = changed_targets.select { |target| target.is_a?(PodTarget) }
          changed_aggregate_targets = changed_targets.select { |target| target.is_a?(AggregateTarget) }

          pod_targets_to_generate = changed_pod_targets + added_pod_targets

          # We either return the full list of aggregate targets or none since the aggregate targets go into the Pods.xcodeproj
          # and so we need to regenerate all aggregate targets when regenerating Pods.xcodeproj.
          aggregate_target_to_generate =
            if !(changed_aggregate_targets + added_aggregate_targets).empty?
              aggregate_targets
            else
              []
              end

          ProjectCacheAnalysisResult.new(pod_targets_to_generate, aggregate_target_to_generate, cache_key_by_target_label,
                                         build_configurations, project_object_version)
        end
      end
    end
  end
end
