module Pod
  class Resolver
    def initialize(specification, dependencies = nil)
      @specification, @dependencies = specification, dependencies || specification.dependencies
    end

    def resolve
      @sets, @loaded_spec_names, @specs = [], [], []
      find_dependency_sets(@specification, @dependencies)
      @specs.sort_by(&:name)
    end

    def find_dependency_sets(specification, dependencies = nil)
      (dependencies || specification.dependencies).each do |dependency|
        set = find_dependency_set(dependency)
        set.required_by(specification)
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
      if external_spec = dependency.specification
        Specification::Set::External.new(external_spec)
      else
        Source.search(dependency)
      end
    end

    def validate_platform!(spec)
      unless spec.platform.nil? || spec.platform == @specification.platform
        raise Informative, "The platform required by the Podfile (:#{@specification.platform}) " \
                           "does not match that of #{spec} (:#{spec.platform})"
      end
    end
  end
end
