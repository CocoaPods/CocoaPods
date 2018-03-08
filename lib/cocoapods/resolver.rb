require 'molinillo'
require 'cocoapods/resolver/lazy_specification'

module Pod
  class NoSpecFoundError < Informative
    def exit_status
      @exit_status ||= 31
    end
  end

  # The resolver is responsible of generating a list of specifications grouped
  # by target for a given Podfile.
  #
  class Resolver
    # A small container that wraps a resolved specification for a given target definition. Additional metadata
    # is included here such as if the specification is only used by tests.
    #
    class ResolverSpecification
      # @return [Specification] the specification that was resolved
      #
      attr_reader :spec

      # @return [Source] the spec repo source the specification came from
      #
      attr_reader :source

      # @return [Bool] whether this resolved specification is only used by tests.
      #
      attr_reader :used_by_tests_only
      alias used_by_tests_only? used_by_tests_only

      def initialize(spec, used_by_tests_only, source)
        @spec = spec
        @used_by_tests_only = used_by_tests_only
        @source = source
      end

      def name
        spec.name
      end

      def root
        spec.root
      end

      def ==(other)
        self.class == other &&
          spec == other.spec &&
          used_by_tests_only == other.test_only
      end
    end

    include Pod::Installer::InstallationOptions::Mixin

    delegate_installation_options { podfile }

    # @return [Sandbox] the Sandbox used by the resolver to find external
    #         dependencies.
    #
    attr_reader :sandbox

    # @return [Podfile] the Podfile used by the resolver.
    #
    attr_reader :podfile

    # @return [Array<Dependency>] the list of dependencies locked to a specific
    #         version.
    #
    attr_reader :locked_dependencies

    # @return [Array<Source>] The list of the sources which will be used for
    #         the resolution.
    #
    attr_reader :sources

    # @return [Bool] Whether the resolver has sources repositories up-to-date.
    #
    attr_reader :specs_updated
    alias specs_updated? specs_updated

    # Init a new Resolver
    #
    # @param  [Sandbox] sandbox @see sandbox
    # @param  [Podfile] podfile @see podfile
    # @param  [Array<Dependency>] locked_dependencies @see locked_dependencies
    # @param  [Array<Source>, Source] sources @see sources
    # @param  [Boolean] specs_updated @see specs_updated
    # @param  [PodfileDependencyCache] podfile_dependency_cache the podfile dependency cache to use
    #         within this Resolver.
    #
    def initialize(sandbox, podfile, locked_dependencies, sources, specs_updated,
                   podfile_dependency_cache: Installer::Analyzer::PodfileDependencyCache.from_podfile(podfile))
      @sandbox = sandbox
      @podfile = podfile
      @locked_dependencies = locked_dependencies
      @sources = Array(sources)
      @specs_updated = specs_updated
      @podfile_dependency_cache = podfile_dependency_cache
      @platforms_by_dependency = Hash.new { |h, k| h[k] = [] }
      @cached_sets = {}
    end

    #-------------------------------------------------------------------------#

    public

    # @!group Resolution

    # Identifies the specifications that should be installed.
    #
    # @return [Hash{TargetDefinition => Array<ResolverSpecification>}] resolver_specs_by_target
    #         the resolved specifications that need to be installed grouped by target
    #         definition.
    #
    def resolve
      dependencies = @podfile_dependency_cache.target_definition_list.flat_map do |target|
        @podfile_dependency_cache.target_definition_dependencies(target).each do |dep|
          next unless target.platform
          @platforms_by_dependency[dep].push(target.platform)
        end
      end
      @platforms_by_dependency.each_value(&:uniq!)
      @activated = Molinillo::Resolver.new(self, self).resolve(dependencies, locked_dependencies)
      resolver_specs_by_target
    rescue Molinillo::ResolverError => e
      handle_resolver_error(e)
    end

    # @return [Hash{Podfile::TargetDefinition => Array<ResolverSpecification>}]
    #         returns the resolved specifications grouped by target.
    #
    # @note   The returned specifications can be subspecs.
    #
    def resolver_specs_by_target
      @resolver_specs_by_target ||= {}.tap do |resolver_specs_by_target|
        dependencies = {}
        @podfile_dependency_cache.target_definition_list.each do |target|
          specs = @podfile_dependency_cache.target_definition_dependencies(target).flat_map do |dep|
            name = dep.name
            node = @activated.vertex_named(name)
            (valid_dependencies_for_target_from_node(target, dependencies, node) << node).map { |s| [s, node.payload.test_specification?] }
          end

          resolver_specs_by_target[target] = specs.
            group_by(&:first).
            map do |vertex, spec_test_only_tuples|
              test_only = spec_test_only_tuples.all? { |tuple| tuple[1] }
              payload = vertex.payload
              spec_source = payload.respond_to?(:spec_source) && payload.spec_source
              ResolverSpecification.new(payload, test_only, spec_source)
            end.
            sort_by(&:name)
        end
      end
    end

    #-------------------------------------------------------------------------#

    public

    # @!group Specification Provider

    include Molinillo::SpecificationProvider

    # Returns (and caches) the specification that satisfy the given dependency.
    #
    # @return [Array<Specification>] the specifications that satisfy the given
    #   `dependency`.
    #
    # @param  [Dependency] dependency the dependency that is being searched for.
    #
    def search_for(dependency)
      @search ||= {}
      @search[dependency] ||= begin
        locked_requirement = requirement_for_locked_pod_named(dependency.name)
        additional_requirements = Array(locked_requirement)
        specifications_for_dependency(dependency, additional_requirements)
      end
      @search[dependency].dup
    end

    # Returns the dependencies of `specification`.
    #
    # @return [Array<Specification>] all dependencies of `specification`.
    #
    # @param  [Specification] specification the specification whose own
    #         dependencies are being asked for.
    #
    def dependencies_for(specification)
      specification.all_dependencies.map do |dependency|
        if dependency.root_name == Specification.root_name(specification.name)
          dependency.dup.tap { |d| d.specific_version = specification.version }
        else
          dependency
        end
      end
    end

    # Returns the name for the given `dependency`.
    #
    # @return [String] the name for the given `dependency`.
    #
    # @param  [Dependency] dependency the dependency whose name is being
    #         queried.
    #
    def name_for(dependency)
      dependency.name
    end

    # @return [String] the user-facing name for a {Podfile}.
    #
    def name_for_explicit_dependency_source
      'Podfile'
    end

    # @return [String] the user-facing name for a {Lockfile}.
    #
    def name_for_locking_dependency_source
      'Podfile.lock'
    end

    # Determines whether the given `requirement` is satisfied by the given
    # `spec`, in the context of the current `activated` dependency graph.
    #
    # @return [Boolean] whether `requirement` is satisfied by `spec` in the
    #         context of the current `activated` dependency graph.
    #
    # @param  [Dependency] requirement the dependency in question.
    #
    # @param  [Molinillo::DependencyGraph] activated the current dependency
    #         graph in the resolution process.
    #
    # @param  [Specification] spec the specification in question.
    #
    def requirement_satisfied_by?(requirement, activated, spec)
      version = spec.version
      return false unless requirement.requirement.satisfied_by?(version)
      shared_possibility_versions, prerelease_requirement = possibility_versions_for_root_name(requirement, activated)
      return false if !shared_possibility_versions.empty? && !shared_possibility_versions.include?(version)
      return false if version.prerelease? && !prerelease_requirement
      return false unless spec_is_platform_compatible?(activated, requirement, spec)
      true
    end

    def possibility_versions_for_root_name(requirement, activated)
      prerelease_requirement = requirement.prerelease? || requirement.external_source
      existing = activated.vertices.values.flat_map do |vertex|
        next unless vertex.payload
        next unless Specification.root_name(vertex.name) == requirement.root_name

        prerelease_requirement ||= vertex.requirements.any? { |r| r.prerelease? || r.external_source }

        if vertex.payload.respond_to?(:possibilities)
          vertex.payload.possibilities.map(&:version)
        else
          vertex.payload.version
        end
      end.compact

      [existing, prerelease_requirement]
    end
    private :possibility_versions_for_root_name

    # Sort dependencies so that the ones that are easiest to resolve are first.
    # Easiest to resolve is (usually) defined by:
    #   1) Is this dependency already activated?
    #   2) How relaxed are the requirements?
    #   3) Are there any conflicts for this dependency?
    #   4) How many possibilities are there to satisfy this dependency?
    #
    # @return [Array<Dependency>] the sorted dependencies.
    #
    # @param  [Array<Dependency>] dependencies the unsorted dependencies.
    #
    # @param  [Molinillo::DependencyGraph] activated the dependency graph of
    #         currently activated specs.
    #
    # @param  [{String => Array<Conflict>}] conflicts the current conflicts.
    #
    def sort_dependencies(dependencies, activated, conflicts)
      dependencies.sort_by do |dependency|
        name = name_for(dependency)
        [
          activated.vertex_named(name).payload ? 0 : 1,
          dependency.external_source ? 0 : 1,
          dependency.prerelease? ? 0 : 1,
          conflicts[name] ? 0 : 1,
          search_for(dependency).count,
        ]
      end
    end

    #-------------------------------------------------------------------------#

    public

    # @!group Resolver UI

    include Molinillo::UI

    # The UI object the resolver should use for displaying user-facing output.
    #
    # @return [UserInterface] the normal CocoaPods UI object.
    #
    def output
      UI
    end

    # Called before resolution starts.
    #
    # Completely silence this, as we show nothing.
    #
    # @return [Void]
    #
    def before_resolution
    end

    # Called after resolution ends.
    #
    # Completely silence this, as we show nothing.
    #
    # @return [Void]
    #
    def after_resolution
    end

    # Called during resolution to indicate progress.
    #
    # Completely silence this, as we show nothing.
    #
    # @return [Void]
    #
    def indicate_progress
    end

    #-------------------------------------------------------------------------#

    private

    # !@ Resolution context

    # @return [Hash<String => Set>] A cache that keeps tracks of the sets
    #         loaded by the resolution process.
    #
    # @note   Sets store the resolved dependencies and return the highest
    #         available specification found in the sources. This is done
    #         globally and not per target definition because there can be just
    #         one Pod installation, so different version of the same Pods for
    #         target definitions are not allowed.
    #
    attr_reader :cached_sets

    #-------------------------------------------------------------------------#

    private

    # @!group Private helpers

    # Returns available specifications which satisfy requirements of given dependency
    # and additional requirements.
    #
    # @param [Dependency] dependency
    #        The dependency whose requirements will be satisfied.
    #
    # @param [Array<Requirement>] additional_requirements
    #        List of additional requirements which should also be satisfied.
    #
    # @return [Array<Specification>] List of specifications satisfying given requirements.
    #
    def specifications_for_dependency(dependency, additional_requirements = [])
      requirement = Requirement.new(dependency.requirement.as_list + additional_requirements.flat_map(&:as_list))
      find_cached_set(dependency).
        all_specifications(installation_options.warn_for_multiple_pod_sources).
        select { |s| requirement.satisfied_by? s.version }.
        map { |s| s.subspec_by_name(dependency.name, false, true) }.
        compact
    end

    # @return [Set] Loads or returns a previously initialized set for the Pod
    #               of the given dependency.
    #
    # @param  [Dependency] dependency
    #         The dependency for which the set is needed.
    #
    # @return [Set] the cached set for a given dependency.
    #
    def find_cached_set(dependency)
      name = dependency.root_name
      unless cached_sets[name]
        if dependency.external_source
          spec = sandbox.specification(name)
          unless spec
            raise StandardError, '[Bug] Unable to find the specification ' \
              "for `#{dependency}`."
          end
          set = Specification::Set::External.new(spec)
        else
          set = create_set_from_sources(dependency)
        end
        cached_sets[name] = set
        unless set
          raise Molinillo::NoSuchDependencyError.new(dependency) # rubocop:disable Style/RaiseArgs
        end
      end
      cached_sets[name]
    end

    # @return [Requirement, Nil]
    #         The {Requirement} that locks the dependency with name `name` in
    #         {#locked_dependencies}.
    #
    def requirement_for_locked_pod_named(name)
      if vertex = locked_dependencies.vertex_named(name)
        if dependency = vertex.payload
          dependency.requirement
        end
      end
    end

    # @return [Set] Creates a set for the Pod of the given dependency from the
    #         sources. The set will contain all versions from all sources that
    #         include the Pod.
    #
    # @param  [Dependency] dependency
    #         The dependency for which the set is needed.
    #
    def create_set_from_sources(dependency)
      aggregate_for_dependency(dependency).search(dependency)
    end

    # @return [Source::Aggregate] The aggregate of the {#sources}.
    #
    def aggregate_for_dependency(dependency)
      if dependency && dependency.podspec_repo
        return Config.instance.sources_manager.aggregate_for_dependency(dependency)
      else
        @aggregate ||= Source::Aggregate.new(sources)
      end
    end

    # Ensures that a specification is compatible with the platform of a target.
    #
    # @raise  If the specification is not supported by the target.
    #
    # @return [void]
    #
    def validate_platform(spec, target)
      return unless target_platform = target.platform
      unless spec.available_platforms.any? { |p| target_platform.to_sym == p.to_sym }
        raise Informative, "The platform of the target `#{target.name}` "     \
          "(#{target.platform}) is not compatible with `#{spec}`, which does "  \
          "not support `#{target.platform.name}`."
      end
    end

    # Handles errors that come out of a {Molinillo::Resolver}.
    #
    # @todo   The check for version conflicts coming from the {Lockfile}
    #         requiring a pre-release version can be deleted for version 1.0,
    #         as it is a migration step for Lockfiles coming from CocoaPods
    #         versions before `0.35.0`.
    #
    # @return [void]
    #
    # @param  [Molinillo::ResolverError] error
    #
    def handle_resolver_error(error)
      message = error.message
      type = Informative
      case error
      when Molinillo::VersionConflict
        message = error.message_with_trees(
          :solver_name => 'CocoaPods',
          :possibility_type => 'pod',
          :version_for_spec => lambda(&:version),
          :additional_message_for_conflict => lambda do |o, name, conflict|
            local_pod_parent = conflict.requirement_trees.flatten.reverse.find(&:local?)
            lockfile_reqs = conflict.requirements[name_for_locking_dependency_source]
            if lockfile_reqs && lockfile_reqs.last && lockfile_reqs.last.prerelease? && !conflict.existing
              o << "\nDue to the previous naïve CocoaPods resolver, " \
                "you were using a pre-release version of `#{name}`, " \
                'without explicitly asking for a pre-release version, which now leads to a conflict. ' \
                'Please decide to either use that pre-release version by adding the ' \
                'version requirement to your Podfile ' \
                "(e.g. `pod '#{name}', '#{lockfile_reqs.map(&:requirement).join("', '")}'`) " \
                "or revert to a stable version by running `pod update #{name}`."
            elsif local_pod_parent && !specifications_for_dependency(conflict.requirement).empty? && !conflict.possibility && conflict.locked_requirement
              # Conflict was caused by a requirement from a local dependency.
              # Tell user to use `pod update`.
              o << "\nIt seems like you've changed the constraints of dependency `#{name}` " \
              "inside your development pod `#{local_pod_parent.name}`.\nYou should run `pod update #{name}` to apply " \
              "changes you've made."
            elsif (conflict.possibility && conflict.possibility.version.prerelease?) &&
                (conflict.requirement && !(
                conflict.requirement.prerelease? ||
                conflict.requirement.external_source)
                )
              # Conflict was caused by not specifying an explicit version for the requirement #[name],
              # and there is no available stable version satisfying constraints for the requirement.
              o << "\nThere are only pre-release versions available satisfying the following requirements:\n"
              conflict.requirements.values.flatten.uniq.each do |r|
                unless search_for(r).empty?
                  o << "\n\t'#{name}', '#{r.requirement}'\n"
                end
              end
              o << "\nYou should explicitly specify the version in order to install a pre-release version"
            elsif !conflict.existing
              conflicts = conflict.requirements.values.flatten.uniq
              found_conflicted_specs = conflicts.reject { |c| search_for(c).empty? }
              if found_conflicted_specs.empty?
                # There are no existing specification inside any of the spec repos with given requirements.
                type = NoSpecFoundError
                dependencies = conflicts.count == 1 ? 'dependency' : 'dependencies'
                o << "\nNone of your spec sources contain a spec satisfying "\
                  "the #{dependencies}: `#{conflicts.join(', ')}`." \
                  "\n\nYou have either:"
                unless specs_updated?
                  o << "\n * out-of-date source repos which you can update with `pod repo update` or with `pod install --repo-update`."
                end
                o << "\n * mistyped the name or version." \
                  "\n * not added the source repo that hosts the Podspec to your Podfile." \
                  "\n\nNote: as of CocoaPods 1.0, `pod repo update` does not happen on `pod install` by default."

              else
                o << "\nSpecs satisfying the `#{conflicts.join(', ')}` dependency were found, " \
                  'but they required a higher minimum deployment target.'
              end
            end
          end,
        )
      end
      raise type.new(message).tap { |e| e.set_backtrace(error.backtrace) }
    end

    # Returns whether the given spec is platform-compatible with the dependency
    # graph, taking into account the dependency that has required the spec.
    #
    # @param  [Molinillo::DependencyGraph] dependency_graph
    #
    # @param  [Dependency] dependency
    #
    # @param  [Specification] specification
    #
    # @return [Bool]
    def spec_is_platform_compatible?(dependency_graph, dependency, spec)
      vertex = dependency_graph.vertex_named(dependency.name)
      predecessors = vertex.recursive_predecessors.select(&:root)
      predecessors << vertex if vertex.root?
      platforms_to_satisfy = predecessors.flat_map(&:explicit_requirements).flat_map { |r| @platforms_by_dependency[r] }.uniq

      available_platforms = spec.available_platforms

      platforms_to_satisfy.all? do |platform_to_satisfy|
        available_platforms.all? do |spec_platform|
          next true unless spec_platform.name == platform_to_satisfy.name
          platform_to_satisfy.supports?(spec_platform)
        end
      end
    end

    # Returns the target-appropriate nodes that are `successors` of `node`,
    # rejecting those that are scoped by target platform and have incompatible
    # targets.
    #
    # @return [Array<Molinillo::DependencyGraph::Vertex>]
    #         An array of target-appropriate nodes whose `payload`s are
    #         dependencies for `target`.
    #
    def valid_dependencies_for_target_from_node(target, dependencies, node)
      dependencies[[node.name, target.platform]] ||= begin
        validate_platform(node.payload, target)
        dependency_nodes = []
        node.outgoing_edges.each do |edge|
          next unless edge_is_valid_for_target_platform?(edge, target.platform)
          dependency_nodes << edge.destination
        end

        dependency_nodes.flat_map do |item|
          valid_dependencies_for_target_from_node(target, dependencies, item)
        end.concat dependency_nodes
      end
    end

    # Whether the given `edge` should be followed to find dependencies for the
    # given `target_platform`.
    #
    # @return [Bool]
    #
    def edge_is_valid_for_target_platform?(edge, target_platform)
      requirement_name = edge.requirement.name

      edge.origin.payload.all_dependencies(target_platform).any? do |dep|
        dep.name == requirement_name
      end
    end
  end
end
