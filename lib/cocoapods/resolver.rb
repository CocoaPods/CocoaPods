module Pod

  # The resolver is responsible of generating a list of specifications grouped
  # by target for a given Podfile.
  #
  # Its current implementation is naive, in the sense that it can't do full
  # automatic resolves like Bundler:
  #
  #   http://patshaughnessy.net/2011/9/24/how-does-bundler-bundle
  #
  # Another important aspect to keep in mind of the current implementation
  # is that the order of the dependencies matters.
  #
  class Resolver
    include Config::Mixin

    # @return [Sandbox] The Sandbox used by the resolver to find external
    #   dependencies.
    #
    attr_reader :sandbox

    # @return [Podfile] The Podfile used by the resolver.
    #
    attr_reader :podfile

    # @return [Array<Dependency>] The list of dependencies locked to a specific
    #   version.
    #
    attr_reader :locked_dependencies

    # @return [Bool] Whether the resolver should update the external specs
    #   in the resolution process. This option is used for detecting changes
    #   in with the Podfile without affecting the existing Pods installation
    #   (see `pod outdated`).
    #
    # @TODO: This implementation is not clean, because if the spec doesn't
    #        exists the sandbox will actually download it and result modified.
    #
    attr_accessor :update_external_specs

    def initialize(sandbox, podfile, locked_dependencies = [])
      @sandbox = sandbox
      @podfile = podfile
      @locked_dependencies = locked_dependencies
    end

    # @return [Hash{Podfile::TargetDefinition => Array<Specification>}]
    #   Returns the resolved specifications grouped by target.
    #
    attr_reader :specs_by_target

    # @return [Array<Specification>] All The specifications loaded by the
    #   resolver.
    #
    def specs
      @cached_specs.values.uniq
    end

    # @return [Array<Strings>] The name of the pods that have an
    #   external source.
    #
    # @TODO: Add an attribute to the specification class?
    #
    attr_reader :pods_from_external_sources

    # @return [Hash{TargetDefinition => Array<Specification>}] specs_by_target
    #   Identifies the specifications that should be installed according
    #   whether the resolver is in update mode or not.
    #
    def resolve
      @cached_sources  = Source::Aggregate.new(config.repos_dir)
      @cached_sets     = {}
      @cached_specs    = {}
      @specs_by_target = {}
      @pods_from_external_sources = []

      podfile.target_definitions.values.each do |target_definition|
        UI.section "Resolving dependencies for target `#{target_definition.name}' (#{target_definition.platform})" do
          @loaded_specs = []
          find_dependency_specs(podfile, target_definition.dependencies, target_definition)
          @specs_by_target[target_definition] = @cached_specs.values_at(*@loaded_specs).sort_by(&:name)
        end
      end

      @cached_specs.values.sort_by(&:name)
      @specs_by_target
    end

      #-----------------------------------------------------------------------#

    private

    # @return [Array<Set>] A cache of the sets used to resolve the dependencies.
    #
    attr_reader :cached_sets


    # @return [Source::Aggregate] A cache of the sources needed to find the
    #   podspecs.
    #
    attr_reader :cached_sources

    # @return [void] Resolves recursively the dependencies of a specification
    #   and stores them in @cached_specs
    #
    # @param [Specification] dependent_specification
    #   The specification whose dependencies are being resolved.
    #
    # @param [Array<Dependency>] dependencies
    #   The dependencies of the specification.
    #
    # @param [TargetDefinition] target_definition
    #   The target definition that owns the specification.
    #
    def find_dependency_specs(dependent_specification, dependencies, target_definition)
      dependencies.each do |dependency|
        # Replace the dependency with a more specific one if the pod is already
        # installed.
        # @TODO: check for compatibility?
        locked_dep = locked_dependencies.find { |locked| locked.name == dependency.name }
        dependency = locked_dep if locked_dep

        UI.message("- #{dependency}", '', 2) do
          set = find_cached_set(dependency, target_definition.platform)
          set.required_by(dependency, dependent_specification.to_s)

          # Ensure we don't resolve the same spec twice for one target
          if @loaded_specs.include?(dependency.name)
            validate_platform(@cached_specs[dependency.name], target_definition)
          else
            spec = set.specification.subspec_by_name(dependency.name)
            @pods_from_external_sources << spec.pod_name if dependency.external?
            @loaded_specs << spec.name
            @cached_specs[spec.name] = spec
            # Configure the specification
            spec.activate_platform(target_definition.platform)
            spec.version.head = dependency.head?
            # And recursively load the dependencies of the spec.
            find_dependency_specs(spec, spec.dependencies, target_definition)

            validate_platform(spec, target_definition)
          end
        end
      end
    end

    # @return [Set] The cached set for a given dependency.
    #
    #   If the update_external_specs flag is activated the dependencies with
    #   external sources are always resolved against the remote. Otherwise the
    #   specification is retrieved from the sandbox that fetches the external
    #   source only if needed.
    #
    def find_cached_set(dependency, platform)
      set_name = dependency.name.split('/').first
      @cached_sets[set_name] ||= begin
        if dependency.specification
          Specification::Set::External.new(dependency.specification)
        elsif external_source = dependency.external_source
          if update_external_specs
            external_source = ExternalSources.from_dependency(dependency)
            spec = external_source.specification_from_external(@sandbox, platform)
          else
            external_source = ExternalSources.from_dependency(dependency)
            spec = external_source.specification_from_sandbox(@sandbox, platform)
          end
          set = Specification::Set::External.new(spec)
          if dependency.subspec_dependency?
            @cached_sets[dependency.root_name] ||= set
          end
          set
        else
          cached_sources.search(dependency)
        end
      end
    end

    # @return [void] Ensures that a spec is compatible with the platform of a
    #   target.
    #
    # @raises If the spec is not supported by the target.
    #
    def validate_platform(spec, target)
      unless spec.available_platforms.any? { |platform| target.platform.supports?(platform) }
        raise Informative, "The platform of the target `#{target.name}' "\
          "(#{target.platform}) is not compatible with `#{spec}' which " \
          "has a minimum requirement of #{spec.available_platforms.join(' - ')}."
      end
    end
  end
end
