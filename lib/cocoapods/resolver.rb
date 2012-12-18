module Pod

  # The resolver is responsible of generating a list of specifications grouped
  # by target for a given Podfile.
  #
  # @todo Its current implementation is naive, in the sense that it can't do full
  #   automatic resolves like Bundler:
  #   [how-does-bundler-bundle](http://patshaughnessy.net/2011/9/24/how-does-bundler-bundle)
  #
  # @todo Another limitation is that the order of the dependencies matter. The
  #   current implementation could create issues, for example, if a
  #   specification is loaded for a target definition and later for another
  #   target is set in head mode. The first specification will not be in head
  #   mode.
  #
  #
  class Resolver

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

    # @param  [Sandbox] sandbox @see sandbox
    # @param  [Podfile] podfile @see podfile
    # @param  [Array<Dependency>] locked_dependencies @see locked_dependencies
    #
    def initialize(sandbox, podfile, locked_dependencies = [])
      @sandbox = sandbox
      @podfile = podfile
      @locked_dependencies = locked_dependencies
      @allow_pre_downloads = true
    end

    # @return [Bool] Whether the resolver should update the external specs
    #         in the resolution process. This option is used for detecting
    #         changes in with the Podfile without affecting the existing Pods
    #         installation
    #
    # @note   This option is used by `pod outdated`.
    #
    attr_accessor :update_external_specs
    alias_method  :update_external_specs?, :update_external_specs

    # @return [Bool] Whether pre-downloads should be allowed. Pre-downloads
    #         change the state of the sandbox and should be allowed only during
    #         installations. Defaults to true.
    #
    # @note   Enabling this if the Podfile and the sandbox are not in sync
    #         might result in an exception.
    #
    attr_accessor :allow_pre_downloads
    alias_method  :allow_pre_downloads?, :allow_pre_downloads

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
      @cached_sources  = SourcesManager.aggregate
      @cached_sets     = {}
      @cached_specs    = {}
      @specs_by_target = {}

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

    #-------------------------------------------------------------------------#

    private

    # !@ Resolution context

    # @return [Source::Aggregate] A cache of the sources needed to find the
    #         podspecs.
    #
    # @note   The sources are cached because frequently accessed by the
    #         resolver and loading them requires disk activity.
    #
    attr_accessor :cached_sources

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

    # !@ Helpers

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
          set = find_cached_set(dependency)
          set.required_by(dependency, dependent_spec.to_s)

          unless @loaded_specs.include?(dependency.name)
            spec = set.specification.subspec_by_name(dependency.name)
            @loaded_specs << spec.name
            cached_specs[spec.name] = spec
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
    #
    # @note   If the {#update_external_specs} flag is activated the
    #         dependencies with external sources are always resolved against
    #         the remote. Otherwise the specification is retrieved from the
    #         sandbox that fetches the external source only if needed.
    #
    # @return [Set] the cached set for a given dependency.
    #
    def find_cached_set(dependency)
      name = dependency.root_name
      unless cached_sets[name]
        if dependency.external_source
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
    # @param  [Dependency] dependency
    #         The dependency with the external source for which the set is
    #         needed.
    #
    # @return [Set] the set for the dependency.
    #
    def set_from_external_source(dependency)
      source = ExternalSources.from_dependency(dependency)
      if allow_pre_downloads?
        if update_external_specs?
          spec = source.specification_from_external(sandbox)
        else
          spec = source.specification(sandbox)
        end
      else
        spec = sandbox.specification(dependency.name)
        unless spec
          raise Informative, "Unable to find the specification for " \
            "`#{dependency}`. Running `pod install` should fix the issue."
        end
      end

      set = Specification::Set::External.new(spec)
    end

    # Ensures that a specification is compatible with the platform of a target.
    #
    # @raise  If the specification is not supported by the target.
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
