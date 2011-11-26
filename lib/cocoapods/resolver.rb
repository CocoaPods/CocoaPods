module Pod
  class Resolver
    # A Resolver::Context caches specification sets and is used by the resolver
    # to ensure that extra dependencies on a set are added to the same instance.
    #
    # In addition, the context is later on used by Specification to lookup other
    # specs, like the on they are a part of.
    class Context
      attr_reader :sources, :sets, :sandbox

      def initialize(sandbox)
        @sandbox = sandbox
        @sets    = {}
        @sources = Source::Aggregate.new
      end

      def find_dependency_set(dependency)
        @sets[dependency.name] ||= begin
          if dependency.specification
            Specification::Set::External.new(dependency.specification)
          elsif external_source = dependency.external_source
            specification = external_source.specification_from_sandbox(@sandbox)
            Specification::Set::External.new(specification)
          else
            @sources.search(dependency)
          end
        end
      end
    end

    attr_reader :podfile, :sandbox
    attr_accessor :context

    def initialize(podfile, sandbox)
      @podfile = podfile
      @sandbox = sandbox
      @context = Context.new(@sandbox)
    end

    def resolve
      @specs = {}

      result = @podfile.target_definitions.values.inject({}) do |result, target_definition|
        @loaded_specs = []
        find_dependency_sets(@podfile, target_definition.dependencies)
        result[target_definition] = @specs.values_at(*@loaded_specs).sort_by(&:name)
        result
      end

      # Specification doesn't need to know more about a context, so we assign
      # the other specification, of which this pod is a part, to the spec.
      @specs.values.sort_by(&:name).each do |spec|
        if spec.part_of_other_pod?
          spec.part_of_specification = @context.sets[spec.part_of.name].specification
        end
      end

      result
    end

    private

    # this can be called with anything that has dependencies
    # e.g. a Specification or a Podfile.
    def find_dependency_sets(specification, dependencies = nil)
      (dependencies || specification.dependencies).each do |dependency|
        set = @context.find_dependency_set(dependency)
        set.required_by(specification)
        unless @loaded_specs.include?(dependency.name)
          # Get a reference to the spec that’s actually being loaded.
          # If it’s a subspec dependency, e.g. 'RestKit/Network', then
          # find that subspec.
          spec = set.specification
          if dependency.subspec_dependency?
            spec = spec.subspec_by_name(dependency.name)
          end

          validate_platform!(spec)

          @loaded_specs << spec.name
          @specs[spec.name] = spec

          # And recursively load the dependencies of the spec.
          find_dependency_sets(spec)
        end
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
