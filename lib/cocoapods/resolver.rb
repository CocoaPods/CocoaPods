require 'colored'

module Pod
  class Resolver
    include Config::Mixin

    # @return [Bool] Whether the resolver should find the pods to install or
    #   the pods to update.
    #
    attr_accessor :update_mode

    # @return [Bool] Whether the resolver should update the external specs
    #   in the resolution process.
    #
    attr_accessor :update_external_specs

    # @return [Podfile] The Podfile used by the resolver.
    #
    attr_reader :podfile

    # @return [Lockfile] The Lockfile used by the resolver.
    #
    attr_reader :lockfile

    # @return [Lockfile] The Sandbox used by the resolver to find external
    #   dependencies.
    #
    attr_reader :sandbox

    # @return [Array<Strings>] The name of the pods coming from an
    #   external sources
    #
    attr_reader :pods_from_external_sources

    # @return [Array<Set>] The set used to resolve the dependencies.
    #
    attr_reader :cached_sets

    # @return [Source::Aggregate] A cache of the sources needed to find the
    #   podspecs.
    #
    attr_reader :cached_sources

    # @return [Hash{Podfile::TargetDefinition => Array<Specification>}]
    #   Returns the resolved specifications grouped by target.
    #
    attr_reader :specs_by_target

    def initialize(podfile, lockfile, sandbox)
      @podfile  = podfile
      @lockfile = lockfile
      @sandbox  = sandbox

      @update_external_specs = true
      @cached_sets = {}
      @cached_sources = Source::Aggregate.new
      @cached_specs = {}
      @specs_by_target = {}
      @pods_from_external_sources = []
      @dependencies_podfile_incompatible = []
      @log_indent = 0;
    end

    # Identifies the specifications that should be installed according whether
    #   the resolver is in update mode or not.
    #
    # @return [Hash{Podfile::TargetDefinition => Array<Specification>}] specs_by_target
    #
    def resolve
      if @lockfile
        puts "\nFinding added, modified or removed dependencies:".green if config.verbose?
        @pods_by_state = @lockfile.detect_changes_with_podfile(podfile)
        if config.verbose?
          @pods_by_state.each do |symbol, pod_names|
            case symbol
            when :added
              mark = "A".green
            when :changed
              mark = "M".yellow
            when :removed
              mark = "R".red
            when :unchanged
              mark = "-"
            end
            pod_names.each do |pod_name|
              puts "  #{mark} " << pod_name
            end
          end
        end
        pods_not_to_lock = @pods_by_state[:added] + @pods_by_state[:changed] + @pods_by_state[:removed]
        lock_versions(lockfile.pods_names - pods_not_to_lock) unless update_mode
      end

      @podfile.target_definitions.values.each do |target_definition|
        puts "\nResolving dependencies for target `#{target_definition.name}' (#{target_definition.platform}):".green if config.verbose?
        @loaded_specs = []
        find_dependency_specs(@podfile, target_definition.dependencies, target_definition)
        @specs_by_target[target_definition] = @cached_specs.values_at(*@loaded_specs).sort_by(&:name)
      end

      @cached_specs.values.sort_by(&:name)
      @specs_by_target
    end

    # @return [Array<Specification>] The specifications loaded by the resolver.
    #
    def specs
      @cached_specs.values.uniq
    end

    # @return [Bool] Whether a pod should be installed/reinstalled.
    #
    def should_install?(name)
      pods_to_install.include? name
    end

    # @return [Array<Strings>] The name of the pods that should be
    #   installed/reinstalled.
    #
    def pods_to_install
      unless @pods_to_install
        if lockfile
          @pods_to_install = specs.select { |spec|
            spec.version != lockfile.pods_versions[spec.pod_name]
          }.map(&:name)
          if update_mode
            @pods_to_install += specs.select { |spec|
              spec.version.head? || pods_from_external_sources.include?(spec.pod_name)
            }.map(&:name)
          end
          @pods_to_install += @pods_by_state[:added] + @pods_by_state[:changed]
        else
          @pods_to_install = specs.map(&:name)
        end
      end
      @pods_to_install
    end

    # @return [Array<Strings>] The name of the pods that were installed
    #   but don't have any dependency anymore. It returns the name
    #   of the Pod stripped from subspecs.
    #
    def removed_pods
      return [] unless lockfile
      unless @removed_pods
        previusly_installed = lockfile.pods_names.map { |pod_name| pod_name.split('/').first }
        installed = specs.map { |spec| spec.name.split('/').first }
        @removed_pods = previusly_installed - installed
      end
      @removed_pods
    end

    private

    # Locks the version of the previously installed pods if they are still
    #   compatible and were required by the Podfile.
    #
    # @return [void]
    #
    def lock_versions(pods)
      return unless lockfile
      # Add a specific Dependency to lock the version in the resolution process
      pods.each do |pod_name|
        version = lockfile.pods_versions[pod_name]
        raise Informative, "Attempt to lock a Pod without an known version." unless version
        dependency = Dependency.new(pod_name, version)
        set = find_cached_set(dependency, nil)
        set.required_by(dependency, lockfile.to_s)
      end
    end

    # @return [Set] The cached set for a given dependency.
    #
    def find_cached_set(dependency, platform)
      set_name = dependency.name.split('/').first
      @cached_sets[set_name] ||= begin
        if dependency.specification
          Specification::Set::External.new(dependency.specification)
        elsif external_source = dependency.external_source
          if update_mode && update_external_specs
            # Always update external sources in update mode.
            specification = external_source.specification_from_external(@sandbox, platform)
          else
            # Don't update external sources in install mode if not needed.
            specification = external_source.specification_from_sandbox(@sandbox, platform)
          end
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

    # Resolves the dependencies of a specification and stores them in @cached_specs
    #
    # @param [Specification] dependent_specification
    # @param [Array<Dependency>] dependencies
    # @param [TargetDefinition] target_definition
    #
    # @return [void]
    #
    def find_dependency_specs(dependent_specification, dependencies, target_definition)
      @log_indent += 1
      dependencies.each do |dependency|
        puts '  ' * @log_indent + "- #{dependency}" if config.verbose?
        set = find_cached_set(dependency, target_definition.platform)
        set.required_by(dependency, dependent_specification.to_s)

        # Ensure we don't resolve the same spec twice for one target
        unless @loaded_specs.include?(dependency.name)
          spec = set.specification_by_name(dependency.name)
          @pods_from_external_sources << spec.pod_name if dependency.external?
          @loaded_specs << spec.name
          @cached_specs[spec.name] = spec
          # Configure the specification
          spec.activate_platform(target_definition.platform)
          spec.version.head = dependency.head?
          # And recursively load the dependencies of the spec.
          find_dependency_specs(spec, spec.dependencies, target_definition) if spec.dependencies
          validate_platform(spec || @cached_specs[dependency.name], target_definition)
        end
      end
      @log_indent -= 1
    end

    # Ensures that a spec is compatible with platform of a target.
    #
    # @raises If the spec is not supported by the target.
    #
    def validate_platform(spec, target)
      unless spec.available_platforms.any? { |platform| target.platform.supports?(platform) }
        raise Informative, "[!] The platform of the target `#{target.name}' (#{target.platform}) is not compatible with `#{spec}' which has a minimun requirement of #{spec.available_platforms.join(' - ')}.".red
      end
    end
  end
end
