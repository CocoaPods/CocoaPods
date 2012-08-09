require 'colored'

module Pod
  class Resolver
    include Config::Mixin

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

    # @return [Bool] Whether the resolver should find the pods to install or
    #   the pods to update.
    #
    attr_accessor :update_mode

    # @return [Bool] Whether the resolver should update the external specs
    #   in the resolution process.
    #
    attr_accessor :updated_external_specs

    # @return [Array<Strings>] The name of the pods coming from an
    #   external sources
    #
    attr_reader :external_pods

    # @return [Array<Set>] The set used to resolve the dependencies.
    #
    attr_accessor :cached_sets

    # @return [Source::Aggregate] A cache of the sources needed to find the
    #   podspecs.
    #
    attr_accessor :cached_sources

    def initialize(podfile, lockfile, sandbox)
      @podfile  = podfile
      @lockfile = lockfile
      @sandbox  = sandbox
      @cached_sets = {}
      @cached_sources = Source::Aggregate.new
      @log_indent = 0;
      @updated_external_specs = true
    end

    # Identifies the specifications that should be installed according whether
    #   the resolver is in update mode or not.
    #
    # @return [void]
    #
    def resolve
      if config.verbose?
        unless podfile_dependencies.empty?
          puts "\nAlready installed Podfile dependencies detected (Podfile.lock):".green
          podfile_dependencies.each {|dependency| puts "  - #{dependency}" }
        end
        unless dependencies_for_pods.empty?
          puts "\nInstalled Pods detected (Podfile.lock):".green
          dependencies_for_pods.each {|dependency| puts "  - #{dependency}" }
        end
      end

      lock_dependencies_version unless update_mode
      @cached_specs = {}
      @targets_and_specs = {}
      @external_pods = []

      @podfile.target_definitions.values.each do |target_definition|
        puts "\nResolving dependencies for target `#{target_definition.name}' (#{target_definition.platform}):".green if config.verbose?
        @loaded_specs = []
        find_dependency_specs(@podfile, target_definition.dependencies, target_definition)
        @targets_and_specs[target_definition] = @cached_specs.values_at(*@loaded_specs).sort_by(&:name)
      end

      @cached_specs.values.sort_by(&:name)
      @targets_and_specs
    end

    # @return [Bool] Whether a pod should be installed/reinstalled.
    #
    def should_install?(name)
      specs_to_install.include?(name)
    end

    # @return [Array<String>] The list of the names of the pods that need
    #   to be installed.
    #
    #   - Install mode: a specification will be installed only if its
    #     dependency in Podfile changed since the last installation.
    #     New Pods will always be installed and Pods already installed will be
    #     reinstalled only if they are not compatible anymore with the Podfile.
    #   - Update mode: a Pod will be installed only if there is a new
    #     version and it was already installed. In no case new Pods will be
    #     installed.
    #
    def specs_to_install
      @specs_to_install ||= begin
        specs = @targets_and_specs.values.flatten
        to_install = []
        specs.each do |spec|
          if update_mode
            # Installation mode
            installed_dependency = dependencies_for_pods.find{|d| d.name == spec.name }
            outdated = installed_dependency && !installed_dependency.matches_spec?(spec)
            head = spec.version.head?
            if outdated || head || @external_pods.include?(spec.pod_name)
              to_install << spec
            end
          else
            # Installation mode
            spec_incompatible_with_podfile = @dependencies_podfile_incompatible.any?{ |d| d.name == spec.name }
            spec_installed = dependencies_for_pods.any?{ |d| d.name == spec.name }
            if !spec_installed || spec_incompatible_with_podfile
              to_install << spec unless @external_pods.include?(spec.pod_name)
            end
          end
        end
        to_install.map{ |s| s.top_level_parent.name }.uniq
      end
    end

    # @return [Array<Specification>] The specifications loaded by the resolver.
    #
    def specs
      @cached_specs.values.uniq
    end


    # @return [Hash{Podfile::TargetDefinition => Array<Specification>}]
    #   Returns the resolved specifications grouped by target.
    #
    def specs_by_target
      @targets_and_specs
    end

    # @return [Array<Strings>] The name of the pods that were installed
    #   but don't have any dependency anymore.
    #
    def removed_pods
      if update_mode
        [] # It should never remove any pod in update mode
      else
        [] # @TODO: Implement
      end
    end

    private

    # Locks the version of the previously installed pods if they are still
    #   compatible and were required by the Podfile.
    #
    # @return [void]
    #
    def lock_dependencies_version
      return unless lockfile
      @dependencies_podfile_incompatible = []
      @removed_pods = []

      puts "\nFinding updated or removed pods:".green if config.verbose?
      podfile_deps_names = podfile_dependencies.map(&:name)

      dependencies_for_pods.each do |dependency|
        # Skip the dependency if it was not requested in the Podfile in the
        # previous installation.
        next unless podfile_deps_names.include?(dependency.name)
        podfile_dependency = podfile.dependencies.find { |d| d.name == dependency.name }
        # Don't lock the dependency if it can't be found in the Podfile as it
        # it means that it was removed.
        unless podfile_dependency
          puts "  R ".red << dependency.to_s if config.verbose?
          @removed_pods << dependency.name #TODO: use the pod name?
          next
        end
        # Check if the dependency necessary to load the pod is still compatible with
        # the podfile.
        # @TODO: pattern match might not be the most appropriate method.
        if podfile_dependency =~ dependency
          puts "  - " << dependency.to_s if config.verbose?
          set = find_cached_set(dependency, nil)
          set.required_by(dependency, lockfile.to_s)
        else
          puts "  U ".yellow << "#{dependency} -> #{podfile_dependency}" if config.verbose?
          @dependencies_podfile_incompatible << dependency
        end
      end
    end

    # @return [Array<Dependency>] Cached copy of the dependencies that require
    #   the installed pods with their exact version.
    #
    def dependencies_for_pods
      @dependencies_for_pods ||= lockfile ? lockfile.dependencies_for_pods : []
    end

    # @return [Array<Dependency>] Cached copy of the Podfile dependencies used
    #   during the last install.
    #
    def podfile_dependencies
      @podfile_dependencies ||= lockfile ? lockfile.podfile_dependencies : []
    end


    # @return [Set] The cached set for a given dependency.
    #
    def find_cached_set(dependency, platform)
      set_name = dependency.name.split('/').first
      @cached_sets[set_name] ||= begin
        if dependency.specification
          Specification::Set::External.new(dependency.specification)
        elsif external_source = dependency.external_source
          # The platform isn't actually being used by the LocalPod instance
          # that's being used behind the scenes, but passing it anyways for
          # completeness sake.
          if update_mode && updated_external_specs
            specification = external_source.specification_from_external(@sandbox, platform)
          else
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
    # @return [void]
    #
    def find_dependency_specs(dependent_specification, dependencies, target_definition)
      @log_indent += 1
      dependencies.each do |dependency|
        puts '  ' * @log_indent + "- #{dependency}" if config.verbose?
        set = find_cached_set(dependency, target_definition.platform)
        set.required_by(dependency, dependent_specification.to_s)

        # Ensure that we don't load new pods in update mode
        # @TODO: filter the dependencies of the target before calling #find_dependency_specs
        if update_mode
        mode_wants_spec = dependencies_for_pods.any?{ |d| d.name == dependency.name }
        else
          mode_wants_spec = true
        end

        # Ensure we don't resolve the same spec twice for one target
        if mode_wants_spec && !@loaded_specs.include?(dependency.name)
          spec = set.specification_by_name(dependency.name)
          @external_pods << spec.pod_name if dependency.external?
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
