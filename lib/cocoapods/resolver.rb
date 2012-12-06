module Pod

  # The resolver is responsible of generating a list of specifications grouped
  # by target for a given Podfile.
  #
  # Its current implementation is naive, in the sense that it can't do full
  # automatic resolves like Bundler:
  # [how-does-bundler-bundle](http://patshaughnessy.net/2011/9/24/how-does-bundler-bundle)
  #
  # Another important aspect to keep in mind of the current implementation
  # is that the order of the dependencies matters.
  #
  class Resolver

    include Config::Mixin

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

    # @return [Bool] whether the resolver should update the external specs
    #         in the resolution process. This option is used for detecting
    #         changes in with the Podfile without affecting the existing Pods
    #         installation
    #
    # @note   This option is used by `pod outdated`.
    #
    # @todo:  This implementation is not clean, because if the spec doesn't
    #         exists the sandbox will actually download and modify the
    #         installation.
    #
    attr_accessor :update_external_specs

    # @param [Sandbox] sandbox @see sandbox
    # @param [Podfile] podfile @see podfile
    # @param [Array<Dependency>] locked_dependencies @see locked_dependencies
    #
    def initialize(sandbox, podfile, locked_dependencies = [])
      @sandbox = sandbox
      @podfile = podfile
      @locked_dependencies = locked_dependencies
    end

    #-------------------------------------------------------------------------#

    # @!group Resolution

    public

    # Identifies the specifications that should be installed.
    #
    # @return [Hash{TargetDefinition => Array<Specification>}] specs_by_target
    #         the specifications that need to be installed grouped by target
    #         definition.
    #
    def resolve
      @cached_sources  = Source::Aggregate.new(config.repos_dir)
      @cached_sets     = {}
      @cached_specs    = {}
      @specs_by_target = {}
      # @pods_from_external_sources = []

      podfile.target_definitions.values.each do |target|
        UI.section "Resolving dependencies for target `#{target.name}' (#{target.platform})" do
          @loaded_specs = []
          find_dependency_specs(podfile, target.dependencies, target)
          specs = cached_specs.values_at(*@loaded_specs).sort_by(&:name)
          specs_by_target[target] = specs
        end
      end

      cached_specs.values.sort_by(&:name)
      specs_by_target
    end

    # @return [Hash{Podfile::TargetDefinition => Array<Specification>}]
    #         returns the resolved specifications grouped by target.
    #
    # @note   The returned specifications can be subspecs.
    #
    attr_reader :specs_by_target

    # @return [Array<Specification>] All the specifications resolved.
    #
    def specs
      specs_by_target.values.flatten.uniq
    end

    # @return [Array<Strings>] The name of the pods that have an
    #         external source.
    #
    # TODO:   Not sure if needed.
    #
    # attr_reader :pods_from_external_sources

    #-------------------------------------------------------------------------#

    # !@ Resolution context

    private

    # @return [Source::Aggregate] A cache of the sources needed to find the
    #         podspecs.
    #
    # @todo   Cache the sources globally?
    #
    attr_accessor :cached_sources

    # @return [Hash<String => Set>] A cache that keeps tracks of the sets
    #         loaded by the resolution process.
    #
    # @note   Sets keep track of the TODO:
    #
    attr_accessor :cached_sets

    #
    #
    attr_accessor :cached_specs

    #
    #
    attr_writer :specs_by_target


    #-------------------------------------------------------------------------#

    # !@ Resolution helpers

    private

    # Resolves recursively the dependencies of a specification and stores them
    # in the @cached_specs ivar.
    #
    # @param  [Podfile, Specification] dependent_spec
    #         the specification whose dependencies are being resolved.
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
    #         not updated the installed pods without without introducing
    #         dependencies in other target definitions.
    #
    # @todo   Just add the requirement to the set?
    # @todo   Use root name?
    #
    # @note   The recursive process checks if a dependency has already been
    #         loaded to prevent an infinite loop. For this reason the
    #         @loaded_specs ivar must be cleaned when changing target
    #         definition.
    #
    #
    # TODO:   The set class should be aware whether it is in head mode.
    #
    # @return [void]
    #
    def find_dependency_specs(dependent_spec, dependencies, target_definition)
      dependencies.each do |dependency|
        locked_dep = locked_dependencies.find { |ld| ld.name == dependency.name }
        dependency = locked_dep if locked_dep

        UI.message("- #{dependency}", '', 2) do
          set = find_cached_set(dependency)
          set.required_by(dependency, dependent_spec.to_s)

          unless @loaded_specs.include?(dependency.name)
            spec = set.specification.subspec_by_name(dependency.name)
            @loaded_specs << spec.name
            cached_specs[spec.name] = spec
            # @pods_from_external_sources << spec.root_name if dependency.external?
            validate_platform(spec, target_definition)
            spec.activate_platform(target_definition.platform)
            spec.version.head = dependency.head?

            find_dependency_specs(spec, spec.dependencies, target_definition)
          end
        end
      end
    end

    # Loads or returns a previously initialized {Set} for the given dependency.
    #
    # @param  [Dependency] dependency
    #         the dependency for which the set is needed.
    #         TODO: check dependency.specification
    #
    # @param [Platform] platform
    #         the platform on which the dependency is needed this is used by
    #         the sandbox to locate external sources.
    #         TODO why?
    #
    # @note   If the {#update_external_specs} flag is activated the
    #         dependencies with external sources are always resolved against
    #         the remote. Otherwise the specification is retrieved from the
    #         sandbox that fetches the external source only if needed.
    #
    # TODO    If the set is loaded from a normal source and then from an
    #         external one that information is lost.
    #
    # @return [Set] the cached set for a given dependency.
    #
    def find_cached_set(dependency)
      name = dependency.root_name
      unless cached_sets[name]
        if dependency.specification
          set = Specification::Set::External.new(dependency.specification)
        elsif dependency.external_source
          set = set_from_external_source(dependency)
        else
          set = cached_sources.search(dependency)
        end
        cached_sets[name] = set
      end
      cached_sets[name]
    end

    # Returns a new set created from an external source
    #
    def set_from_external_source(dependency)
      source = ExternalSources.from_dependency(dependency)
      if update_external_specs
        spec = source.specification_from_external(sandbox)
      else
        spec = source.specification(sandbox)
      end
      set = Specification::Set::External.new(spec)
      set
    end

    # Ensures that a spec is compatible with the platform of a target.
    #
    # @raises If the spec is not supported by the target.
    #
    # @return [void]
    #
    def validate_platform(spec, target)
      unless spec.available_platforms.any? { |p| target.platform.supports?(p) }
        raise Informative, "The platform of the target `#{target.name}` "     \
          "(#{target.platform}) is not compatible with `#{spec}` which has "  \
          "a minimum requirement of #{spec.available_platforms.join(' - ')}."
      end
    end
  end
end
