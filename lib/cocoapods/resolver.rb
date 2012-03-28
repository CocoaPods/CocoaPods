module Pod
  class Resolver
    include Config::Mixin

    attr_reader :podfile, :sandbox
    attr_accessor :cached_sets, :cached_sources

    def initialize(podfile, sandbox)
      @podfile = podfile
      @sandbox = sandbox
      @cached_sets = {}
      @cached_sources = Source::Aggregate.new
      @log_indent = 0;
    end

    def resolve
      @specs = {}

      result = @podfile.target_definitions.values.inject({}) do |result, target_definition|
        puts "\Resolving dependencies for target `#{target_definition.name}'".green if config.verbose?
        @loaded_specs = []
        find_dependency_sets(@podfile, target_definition.dependencies)
        result[target_definition] = @specs.values_at(*@loaded_specs).sort_by(&:name)
        result
      end

      # Specification doesn't need to know more about the context, so we assign
      # the other specification, of which this pod is a part, to the spec.
      @specs.values.sort_by(&:name).each do |spec|
        if spec.part_of_other_pod?
          spec.part_of_specification = @cached_sets[spec.part_of.name].specification
        end
      end

      result
    end

    private

    def find_cached_set(dependency)
      @cached_sets[dependency.name] ||= begin
        if dependency.specification
          Specification::Set::External.new(dependency.specification)
        elsif external_source = dependency.external_source
          specification = external_source.specification_from_sandbox(@sandbox)
          Specification::Set::External.new(specification)
        else
          @cached_sources.search(dependency)
        end
      end
    end

    def find_dependency_sets(dependent_specification, dependencies)
      @log_indent += 1
      dependencies.each do |dependency|
        puts '  ' * @log_indent + "- #{dependency}" if config.verbose?
        set = find_cached_set(dependency)
        set.required_by(dependent_specification)
        # Ensure we don't resolve the same spec twice
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
          find_dependency_sets(spec, spec.dependencies)
        end
      end
      @log_indent -= 1
    end

    def validate_platform!(spec)
      unless spec.platform.nil? || spec.platform == @podfile.platform
        raise Informative, "The platform required by the Podfile (:#{@podfile.platform}) " \
                           "does not match that of #{spec} (:#{spec.platform})"
      end
    end
  end
end
