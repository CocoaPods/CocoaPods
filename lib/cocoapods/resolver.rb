require 'colored'

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
      targets_and_specs = {}

      @podfile.target_definitions.values.each do |target_definition|
        puts "\nResolving dependencies for target `#{target_definition.name}' (#{target_definition.platform})".green if config.verbose?
        @loaded_specs = []
        # TODO @podfile.platform will change to target_definition.platform
        find_dependency_sets(@podfile, target_definition.dependencies, target_definition)
        targets_and_specs[target_definition] = @specs.values_at(*@loaded_specs).sort_by(&:name)
      end

      # Specification doesn't need to know more about the context, so we assign
      # the other specification, of which this pod is a part, to the spec.
      @specs.values.sort_by(&:name).each do |spec|
        if spec.part_of_other_pod?
          spec.part_of_specification = @cached_sets[spec.part_of.name].specification
        end
      end

      targets_and_specs
    end

    private

    def find_cached_set(dependency, platform)
      @cached_sets[dependency.name] ||= begin
        if dependency.specification
          Specification::Set::External.new(dependency.specification)
        elsif external_source = dependency.external_source
          # The platform isn't actually being used by the LocalPod instance
          # that's being used behind the scenes, but passing it anyways for
          # completeness sake.
          specification = external_source.specification_from_sandbox(@sandbox, platform)
          Specification::Set::External.new(specification)
        else
          @cached_sources.search(dependency)
        end
      end
    end

    def find_dependency_sets(dependent_specification, dependencies, target_definition)
      @log_indent += 1
      dependencies.each do |dependency|
        puts '  ' * @log_indent + "- #{dependency}" if config.verbose?
        set = find_cached_set(dependency, target_definition.platform)
        set.required_by(dependent_specification)
        # Ensure we don't resolve the same spec twice for one target
        unless @loaded_specs.include?(dependency.name)
          # Get a reference to the spec that’s actually being loaded.
          # If it’s a subspec dependency, e.g. 'RestKit/Network', then
          # find that subspec.
          spec = set.specification
          if dependency.subspec_dependency?
            spec = spec.subspec_by_name(dependency.name)
          end

          validate_platform!(spec, target_definition)

          @loaded_specs << spec.name
          @specs[spec.name] = spec

          # And recursively load the dependencies of the spec.
          # TODO fix the need to return an empty arrayf if there are no deps for the given platform
          find_dependency_sets(spec, (spec.dependencies[target_definition.platform.to_sym] || []), target_definition)
        end
      end
      @log_indent -= 1
    end

    def validate_platform!(spec, target)
      unless target.platform.support?(spec.platform)
        raise Informative, "[!] The platform required by the target `#{target.name}' `#{target.platform}' does not match that of #{spec} `#{spec.platform}'".red
      end
    end
  end
end
