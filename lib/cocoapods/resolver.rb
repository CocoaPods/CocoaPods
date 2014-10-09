module Resolver
  require 'resolver'
  class DependencyGraph
    class Vertex
      def recursive_successors
        successors + successors.map(&:recursive_successors).reduce(Set.new, &:+)
      end
    end
  end
  class ResolverError
    require 'claide'
    include CLAide::InformativeError
  end
end

module Pod
  class Specification::Set
    class LazySpecification < BasicObject
      attr_reader :name, :version, :source

      def initialize(name, version, source)
        @name = name
        @version = version
        @source = source
      end

      def method_missing(method, *args, &block)
        specification.send(method, *args, &block)
      end

      def subspec_by_name(name = nil)
        if !name || name == self.name
          self
        else
          specification.subspec_by_name(name)
        end
      end

      def specification
        @specification ||= source.specification(name, version)
      end
    end

    def all_specifications
      @all_specifications ||= versions_by_source.map do |source, versions|
        versions.map { |version| LazySpecification.new(name, version, source) }
      end.flatten
    end
  end

  class Specification::Set::External
    def all_specifications
      [specification]
    end
  end

  # The resolver is responsible of generating a list of specifications grouped
  # by target for a given Podfile.
  #
  class Resolver
    require 'resolver'
    include ::Resolver::UI
    include ::Resolver::SpecificationProvider

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
    attr_accessor :sources

    # @param  [Sandbox] sandbox @see sandbox
    # @param  [Podfile] podfile @see podfile
    # @param  [Array<Dependency>] locked_dependencies @see locked_dependencies
    # @param  [Array<Source>, Source] sources @see sources
    #
    def initialize(sandbox, podfile, locked_dependencies, sources)
      @sandbox = sandbox
      @podfile = podfile
      @locked_dependencies = locked_dependencies
      @sources = Array(sources)
    end

    #-------------------------------------------------------------------------#

    public

    # @!group Resolution

    # Identifies the specifications that should be installed.
    #
    # @return [Hash{TargetDefinition => Array<Specification>}] specs_by_target
    #         the specifications that need to be installed grouped by target
    #         definition.
    #
    def resolve
      @cached_specs = {}
      @cached_sets = {}
      @activated = ::Resolver::Resolver.new(self, self).
        resolve(
          @podfile.target_definition_list.map(&:dependencies).flatten,
          locked_dependencies.reduce(::Resolver::DependencyGraph.new) do |graph, locked|
            graph.tap { |g| g.add_root_vertex(locked.name, locked) }
          end
        )
      specs_by_target
    rescue ::Resolver::ResolverError => e
      raise Informative, e.message
    end

    def search_for(dependency)
      @search ||= {}
      @search[dependency] ||= begin
        prerelease_requirement = dependency.
          requirement.
          requirements.
          any? { |r| Version.new(r[1].version).prerelease? }

        find_cached_set(dependency).
          all_specifications.
          select { |s| dependency.requirement.satisfied_by? Version.new(s.version) }.
          reject { |s| !prerelease_requirement && s.version.prerelease? }.
          reverse.
          map { |s| s.subspec_by_name dependency.name rescue nil }.
          compact.
          each { |s| s.version.head = dependency.head? }
      end
      @search[dependency].dup
    end

    def dependencies_for(dependency)
      dependency.all_dependencies
    end

    def name_for(dependency)
      dependency.name
    end

    def requirement_satisfied_by?(requirement, activated, spec)
      existing = activated.vertices.values.map(&:payload).compact.find { |s| Specification.root_name(s.name) ==  Specification.root_name(requirement.name) }
      if existing
        existing.version == spec.version &&
          requirement.requirement.satisfied_by?(spec.version)
      else
        requirement.requirement.satisfied_by? spec.version
      end
    end

    # Sort dependencies so that the ones that are easiest to resolve are first.
    # Easiest to resolve is (usually) defined by:
    #   1) Is this dependency already activated?
    #   2) How relaxed are the requirements?
    #   3) Are there any conflicts for this dependency?
    #   4) How many possibilities are there to satisfy this dependency?
    #
    def sort_dependencies(dependencies, activated, conflicts)
      dependencies.sort_by do |dependency|
        name = name_for(dependency)
        [
          activated.vertex_named(name).payload ? 0 : 1,
          conflicts[name] ? 0 : 1,
          search_for(dependency).count,
        ]
      end
    end

    # @return [Hash{Podfile::TargetDefinition => Array<Specification>}]
    #         returns the resolved specifications grouped by target.
    #
    # @note   The returned specifications can be subspecs.
    #
    def specs_by_target
      @specs_by_target ||= begin
        specs_by_target = {}
        podfile.target_definition_list.each do |target|
          specs_by_target[target] = target.dependencies.map(&:name).map do |name|
            node = @activated.vertex_named(name)
            (node.recursive_successors << node).to_a
          end.
            flatten.
            map(&:payload).
            uniq.
            sort { |x, y| x.name <=> y.name }.
            each do |spec|
              unless spec.available_platforms.any? { |p| target.platform.supports?(p) }
                raise Informative, "The platform of the target `#{target.name}` "     \
                  "(#{target.platform}) is not compatible with `#{spec}` which has "  \
                  "a minimum requirement of #{spec.available_platforms.join(' - ')}."
                end
              sandbox.store_head_pod(spec.name) if spec.version.head
            end
        end
        specs_by_target
      end
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
    attr_accessor :cached_sets

    # @return [Hash<String => Specification>] The loaded specifications grouped
    #         by name.
    #
    attr_accessor :cached_specs

    #-------------------------------------------------------------------------#

    private

    # @!group Private helpers

    # Resolves recursively the dependencies of a specification and stores them
    # in the @cached_specs ivar.
    #
    # @param  [Podfile, Specification, #to_s] dependent_spec
    #         the specification whose dependencies are being resolved. Used
    #         only for UI purposes.
    #
    # @param  [Array<Dependency>] dependencies
    #         the dependencies of the specification.
    #
    # @param  [TargetDefinition] target_definition
    #         the target definition that owns the specification.
    #
    # @note   If there is a locked dependency with the same name of a
    #         given dependency the locked one is used in place of the
    #         dependency of the specification. In this way it is possible to
    #         prevent the update of the version of installed pods not changed
    #         in the Podfile.
    #
    # @note   The recursive process checks if a dependency has already been
    #         loaded to prevent an infinite loop.
    #
    # @note   The set class merges all (of all the target definitions) the
    #         dependencies and thus it keeps track of whether it is in head
    #         mode or from an external source because {Dependency#merge}
    #         preserves this information.
    #
    # @return [void]
    #
    def find_dependency_specs(dependent_spec, dependencies, target_definition)
      dependencies.each do |dependency|
        locked_dep = locked_dependencies.find { |ld| ld.name == dependency.name }
        dependency = locked_dep if locked_dep

        UI.message("- #{dependency}", '', 2) do
          set = find_cached_set(dependency, dependent_spec)
          set.required_by(dependency, dependent_spec.to_s)

          if (paths = set.specification_paths_for_version(set.required_version)).length > 1
            UI.warn "Found multiple specifications for #{dependency}:\n" \
              "- #{paths.join("\n")}"
          end

          unless @loaded_specs.include?(dependency.name)
            spec = set.specification.subspec_by_name(dependency.name)
            @loaded_specs << spec.name
            cached_specs[spec.name] = spec
            validate_platform(spec, target_definition)
            if dependency.head? || sandbox.head_pod?(spec.name)
              spec.version.head = true
              sandbox.store_head_pod(spec.name)
            end

            spec_dependencies = spec.all_dependencies(target_definition.platform)
            find_dependency_specs(spec, spec_dependencies, target_definition)
          end
        end
      end
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
          spec = sandbox.specification(dependency.root_name)
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
          raise Informative, 'Unable to find a specification for ' \
            "`#{dependency}`."
        end
      end
      cached_sets[name]
    end

    # @return [Set] Creates a set for the Pod of the given dependency from the
    #         sources. The set will contain all versions from all sources that
    #         include the Pod.
    #
    # @param  [Dependency] dependency
    #         The dependency for which the set is needed.
    #
    def create_set_from_sources(dependency)
      aggregate.search(dependency)
    end

    # @return [Source::Aggregate] The aggregate of the {#sources}.
    #
    def aggregate
      @aggregate ||= Source::Aggregate.new(sources.map(&:repo))
    end
  end
end
