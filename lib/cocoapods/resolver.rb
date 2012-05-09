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

      @specs.values.sort_by(&:name)

      targets_and_specs
    end

    private

    def find_cached_set(dependency, platform)
      set_name = dependency.name.split('/').first
      @cached_sets[set_name] ||= begin
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

          @loaded_specs << spec.name
          @specs[spec.name] = spec

          # And recursively load the dependencies of the spec.
          # TODO fix the need to return an empty arrayf if there are no deps for the given platform
          find_dependency_sets(spec, (spec.dependencies[target_definition.platform.to_sym] || []), target_definition)
        end
        validate_platform!(spec || @specs[dependency.name], target_definition)
      end
      @log_indent -= 1
    end

    def validate_platform!(spec, target)
      unless spec.available_platforms.any? { |platform| target.platform.support?(platform) }
        raise Informative, "[!] The platform of the target `#{target.name}' (#{target.platform}) is not compatible with `#{spec}' which has a minimun requirement of #{spec.available_platforms.join(' - ')}.".red
      end
    end
  end
end
