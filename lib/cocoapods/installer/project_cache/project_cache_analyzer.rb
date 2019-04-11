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

        # @return [Integer] The object version from the user project.
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
        # @param [Integer] project_object_version @see #project_object_version
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
          cache_key_by_target_label = create_cache_key_mappings(target_by_label)

          full_install_results = ProjectCacheAnalysisResult.new(pod_targets, aggregate_targets, cache_key_by_target_label,
                                                                build_configurations, project_object_version)
          if clean_install
            UI.message 'Ignoring project cache from the provided `--clean-install` flag.'
            return full_install_results
          end

          # Bail out early since these properties affect all targets and their associate projects.
          if cache.build_configurations != build_configurations || cache.project_object_version != project_object_version
            UI.message 'Ignoring project cache due to project configuration changes.'
            return full_install_results
          end

          pod_targets_to_generate = Set[]
          aggregate_targets_to_generate = Set[]
          added_targets, removed_targets = compute_added_and_removed_targets(target_by_label,
                                                                             cache_key_by_target_label.keys,
                                                                             cache.cache_key_by_target_label.keys)
          added_pod_targets, added_aggregate_targets = added_targets.partition { |target| target.is_a?(PodTarget) }
          removed_aggregate_targets = removed_targets.select { |target| target.is_a?(AggregateTarget) }
          pod_targets_to_generate.merge(added_pod_targets)
          aggregate_targets_to_generate.merge(added_aggregate_targets + removed_aggregate_targets)

          changed_targets = compute_changed_targets_from_cache(cache_key_by_target_label, target_by_label, cache)
          changed_pod_targets, changed_aggregate_targets = changed_targets.partition { |target| target.is_a?(PodTarget) }
          pod_targets_to_generate.merge(changed_pod_targets)
          aggregate_targets_to_generate.merge(changed_aggregate_targets)

          dirty_targets = compute_dirty_targets(pod_targets + aggregate_targets)
          dirty_pod_targets, dirty_aggregate_targets = dirty_targets.partition { |target| target.is_a?(PodTarget) }
          pod_targets_to_generate.merge(dirty_pod_targets)
          aggregate_targets_to_generate.merge(dirty_aggregate_targets)

          # Since multi xcodeproj will group targets by PodTarget#pod_name into individual projects, we
          # need to append these "sibling" targets to the list of targets we need to generate before finalizing the total list,
          # otherwise we will end up with missing targets.
          #
          sibling_pod_targets = compute_sibling_pod_targets(pod_targets, pod_targets_to_generate)
          pod_targets_to_generate.merge(sibling_pod_targets)

          # We either return the full list of aggregate targets or none since the aggregate targets go into the Pods.xcodeproj
          # and so we need to regenerate all aggregate targets when regenerating Pods.xcodeproj.

          total_aggregate_targets_to_generate =
            unless aggregate_targets_to_generate.empty?
              aggregate_targets
            end

          ProjectCacheAnalysisResult.new(pod_targets_to_generate.to_a, total_aggregate_targets_to_generate, cache_key_by_target_label,
                                         build_configurations, project_object_version)
        end

        private

        def create_cache_key_mappings(target_by_label)
          Hash[target_by_label.map do |label, target|
            case target
            when PodTarget
              local = sandbox.local?(target.pod_name)
              checkout_options = sandbox.checkout_sources[target.pod_name]
              [label, TargetCacheKey.from_pod_target(target, :is_local_pod => local, :checkout_options => checkout_options)]
            when AggregateTarget
              [label, TargetCacheKey.from_aggregate_target(target)]
            else
              raise "[BUG] Unknown target type #{target}"
            end
          end]
        end

        def compute_added_and_removed_targets(target_by_label, target_labels, cached_target_labels)
          added_targets = (target_labels - cached_target_labels).map do |label|
            target_by_label[label]
          end
          removed_targets = (cached_target_labels - target_labels).map do |label|
            target_by_label[label]
          end
          [added_targets, removed_targets]
        end

        def compute_changed_targets_from_cache(cache_key_by_target_label, target_by_label, cache)
          cache_key_by_target_label.each_with_object([]) do |(label, cache_key), changed_targets|
            next unless cache.cache_key_by_target_label[label]
            if cache_key.key_difference(cache.cache_key_by_target_label[label]) == :project
              changed_targets << target_by_label[label]
            end
          end
        end

        def compute_dirty_targets(targets)
          targets.reject do |target|
            support_files_dir_exists = File.exist? target.support_files_dir
            xcodeproj_exists = case target
                               when PodTarget
                                 File.exist? sandbox.pod_target_project_path(target.pod_name)
                               when AggregateTarget
                                 File.exist? sandbox.project_path
                               else
                                 raise "[BUG] Unknown target type #{target}"
                               end
            support_files_dir_exists && xcodeproj_exists
          end
        end

        def compute_sibling_pod_targets(pod_targets, pod_targets_to_generate)
          pod_targets_by_name = pod_targets.group_by(&:pod_name)
          pod_targets_to_generate.flat_map { |t| pod_targets_by_name[t.pod_name] }
        end
      end
    end
  end
end
