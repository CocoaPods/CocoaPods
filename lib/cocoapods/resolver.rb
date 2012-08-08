require 'colored'

module Pod
  class Resolver
    include Config::Mixin

    attr_reader :podfile, :lockfile, :sandbox
    attr_accessor :cached_sets, :cached_sources, :update_mode

    def initialize(podfile, lockfile, sandbox)
      @podfile  = podfile
      @lockfile = lockfile
      @sandbox  = sandbox
      @cached_sets = {}
      @cached_sources = Source::Aggregate.new
      @log_indent = 0;

    end

    def installed_dependencies
      @installed_dependencies ||= lockfile ? lockfile.installed_dependencies : []
    end

    def should_install?(name)
      names_of_pods_installs = specs_to_install.map(&:name)
      names_of_pods_installs.include?(name)
    end

    def specs_to_install
      if update_mode
        specs = @targets_and_specs.values.flatten
        outdated_specs = []
        specs.each do |spec|
          if spec_outdated?(spec)
            outdated_specs << spec
          end
        end
        outdated_specs
      else
        specs = @targets_and_specs.values.flatten
        outdated_specs = []
        specs.each do |spec|
          unless spec_installed?(spec)
            outdated_specs << spec
          end
        end
        outdated_specs
        # Implement this forces the installer to install only the specs that don't have a folder.
        # Should install also if there was a change in the podfile
        # Disambiguate dependecies before resolution?
        []
      end
    end

    def specs_by_target
      @targets_and_specs
    end

    def resolve
      if lockfile
        if config.verbose?
          puts "\nInstalled podfile dependencies detected in: #{lockfile.defined_in_file}".green
          lockfile.podfile_dependencies.each {|dependency| puts "  - #{dependency}" }
          puts "\nInstalled pods versions detected in: #{lockfile.defined_in_file}".green
          lockfile.installed_dependencies.each {|dependency| puts "  - #{dependency}" }
        end
      end

      unless update_mode || !lockfile
        puts "\nLocking dependencies to installed versions:".green if config.verbose?
        # Add the installed specs which are still compatible with podfile
        # requirements to activated
        installed_dependencies.each do |dependency|
          compatible_with_podfile = dependency && true
          if compatible_with_podfile
            puts "  - #{dependency}" if config.verbose?
            set = find_cached_set(dependency, nil)
            set.required_by(dependency, lockfile.to_s)
          end
        end
      end

      @specs = {}
      @targets_and_specs = {}

      @podfile.target_definitions.values.each do |target_definition|
        puts "\nResolving dependencies for target `#{target_definition.name}' (#{target_definition.platform})".green if config.verbose?
        @loaded_specs = []
        find_dependency_specs(@podfile, target_definition.dependencies, target_definition)
        @targets_and_specs[target_definition] = @specs.values_at(*@loaded_specs).sort_by(&:name)
      end

      @specs.values.sort_by(&:name)
      @targets_and_specs
    end

    private

    def dependency_installed?(dependency)
      installed_dependencies.any?{ |installed_dependency| installed_dependency.name == dependency.name }
    end

    def spec_installed?(spec)
      installed_dependencies.any?{ |installed_dependency| installed_dependency.name == spec.name }
    end

    def spec_outdated?(spec)
      installed_dependency = installed_dependencies.find{|installed_dependency| installed_dependency.name == spec.name }
      installed_dependency && !installed_dependency.matches_spec?(spec)
    end

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
          set = Specification::Set::External.new(specification)
          if dependency.subspec_dependency?
            @cached_sets[dependency.top_level_spec_name] ||= set
          end
          set
        else
          @cached_sources.search(dependency)
        end
      end
    end

    def find_dependency_specs(dependent_specification, dependencies, target_definition)
      @log_indent += 1
      dependencies.each do |dependency|
        puts '  ' * @log_indent + "- #{dependency}" if config.verbose?
        set = find_cached_set(dependency, target_definition.platform)
        set.required_by(dependency, dependent_specification.to_s)

        if update_mode
          mode_wants_spec = dependency_installed?(dependency)
        else
          mode_wants_spec = true
        end

        # Ensure we don't resolve the same spec twice for one target
        if mode_wants_spec && !@loaded_specs.include?(dependency.name)
          spec = set.specification_by_name(dependency.name)
          @loaded_specs << spec.name
          @specs[spec.name] = spec
          # Configure the specification
          spec.activate_platform(target_definition.platform)
          spec.version.head = dependency.head?
          # And recursively load the dependencies of the spec.
          find_dependency_specs(spec, spec.dependencies, target_definition) if spec.dependencies
          validate_platform!(spec || @specs[dependency.name], target_definition)
        end
      end
      @log_indent -= 1
    end

    def validate_platform!(spec, target)
      unless spec.available_platforms.any? { |platform| target.platform.supports?(platform) }
        raise Informative, "[!] The platform of the target `#{target.name}' (#{target.platform}) is not compatible with `#{spec}' which has a minimun requirement of #{spec.available_platforms.join(' - ')}.".red
      end
    end
  end
end
