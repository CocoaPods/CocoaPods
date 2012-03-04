module Pod
  class Resolver
    def initialize(podfile, sandbox)
      @podfile = podfile
      @sandbox = sandbox
    end

    def resolve
      @podfile.target_definitions.values.inject({}) do |result, target_definition|
        @sets, @loaded_spec_names, @specs = [], [], []
        find_dependency_sets(@podfile, target_definition.dependencies)
        result[target_definition] = @specs.sort_by(&:name)
        result
      end
    end

    # this can be called with anything that has dependencies
    # e.g. a Specification or a Podfile.
    def find_dependency_sets(has_dependencies, dependency_subset = nil)
      (dependency_subset || has_dependencies.dependencies).each do |dependency|
        set = find_dependency_set(dependency)
        set.required_by(has_dependencies)
        unless @loaded_spec_names.include?(dependency.name)
          # Get a reference to the spec that’s actually being loaded.
          # If it’s a subspec dependency, e.g. 'RestKit/Network', then
          # find that subspec.
          spec = set.specification
          if dependency.subspec_dependency?
            spec = spec.subspec_by_name(dependency.name)
          end
          validate_platform!(spec)

          # Ensure we don't resolve the same spec twice
          @loaded_spec_names << spec.name
          @specs << spec
          @sets << set unless @sets.include?(set)

          find_dependency_sets(spec)
        end
      end
    end

    def find_dependency_set(dependency)
      if dependency.specification
        Specification::Set::External.new(dependency.specification)
      elsif external_source = dependency.external_source
        specification = external_source.specification_from_sandbox(@sandbox)
        Specification::Set::External.new(specification)
      else
        Source.search(dependency)
      end
    end

    def validate_platform!(spec)
      unless spec.platform.nil? || spec.platform == @podfile.platform
        raise Informative, "The platform required by the Podfile (:#{@podfile.platform}) " \
                           "does not match that of #{spec} (:#{spec.platform})"
      end
    end
  end
end
