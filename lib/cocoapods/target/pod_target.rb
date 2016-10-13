module Pod
  # Stores the information relative to the target used to compile a single Pod.
  # A pod can have one or more activated spec/subspecs.
  #
  class PodTarget < Target
    # @return [Array<Specification>] the spec and subspecs for the target.
    #
    attr_reader :specs

    # @return [Array<PBXNativeTarget>] the target definitions of the Podfile
    #         that generated this target.
    #
    attr_reader :target_definitions

    # @return [HeadersStore] the header directory for the target.
    #
    attr_reader :build_headers

    # @return [String] used as suffix in the label
    #
    # @note This affects the value returned by #configuration_build_dir
    #       and accessors relying on this as #build_product_path.
    #
    attr_reader :scope_suffix

    # @return [Array<PodTarget>] the targets that this target has a dependency
    #         upon.
    #
    attr_accessor :dependent_targets

    # @param [Array<Specification>] specs @see #specs
    # @param [Array<TargetDefinition>] target_definitions @see #target_definitions
    # @param [Sandbox] sandbox @see #sandbox
    # @param [String] scope_suffix @see #scope_suffix
    #
    def initialize(specs, target_definitions, sandbox, scope_suffix = nil)
      raise "Can't initialize a PodTarget without specs!" if specs.nil? || specs.empty?
      raise "Can't initialize a PodTarget without TargetDefinition!" if target_definitions.nil? || target_definitions.empty?
      raise "Can't initialize a PodTarget with only abstract TargetDefinitions" if target_definitions.all?(&:abstract?)
      raise "Can't initialize a PodTarget with an empty string scope suffix!" if scope_suffix == ''
      super()
      @specs = specs
      @target_definitions = target_definitions
      @sandbox = sandbox
      @scope_suffix = scope_suffix
      @build_headers  = Sandbox::HeadersStore.new(sandbox, 'Private')
      @file_accessors = []
      @resource_bundle_targets = []
      @dependent_targets = []
      @build_config_cache = {}
    end

    # @param [Hash{Array => PodTarget}] cache
    #        the cached PodTarget for a previously scoped (specs, target_definition)
    # @return [Array<PodTarget>] a scoped copy for each target definition.
    #
    def scoped(cache = {})
      target_definitions.map do |target_definition|
        cache_key = [specs, target_definition]
        if cache[cache_key]
          cache[cache_key]
        else
          target = PodTarget.new(specs, [target_definition], sandbox, target_definition.label)
          target.file_accessors = file_accessors
          target.user_build_configurations = user_build_configurations
          target.native_target = native_target
          target.archs = archs
          target.dependent_targets = dependent_targets.flat_map { |pt| pt.scoped(cache) }.select { |pt| pt.target_definitions == [target_definition] }
          target.host_requires_frameworks = host_requires_frameworks
          cache[cache_key] = target
        end
      end
    end

    # @return [String] the label for the target.
    #
    def label
      if scope_suffix.nil? || scope_suffix[0] == '.'
        "#{root_spec.name}#{scope_suffix}"
      else
        "#{root_spec.name}-#{scope_suffix}"
      end
    end

    # @return [String] the Swift version for the target.
    #
    def swift_version
      target_definitions.map(&:swift_version).compact.uniq.first
    end

    # @note   The deployment target for the pod target is the maximum of all
    #         the deployment targets for the current platform of the target
    #         (or the minimum required to support the current installation
    #         strategy, if higher).
    #
    # @return [Platform] the platform for this target.
    #
    def platform
      @platform ||= begin
        platform_name = target_definitions.first.platform.name
        default = Podfile::TargetDefinition::PLATFORM_DEFAULTS[platform_name]
        deployment_target = specs.map do |spec|
          Version.new(spec.deployment_target(platform_name) || default)
        end.max
        if platform_name == :ios && requires_frameworks?
          minimum = Version.new('8.0')
          deployment_target = [deployment_target, minimum].max
        end
        Platform.new(platform_name, deployment_target)
      end
    end

    # @visibility private
    #
    attr_writer :platform

    # @return [Podfile] The podfile which declares the dependency.
    #
    def podfile
      target_definitions.first.podfile
    end

    # @return [String] The name to use for the source code module constructed
    #         for this target, and which will be used to import the module in
    #         implementation source files.
    #
    def product_module_name
      root_spec.module_name
    end

    # @return [Array<Sandbox::FileAccessor>] the file accessors for the
    #         specifications of this target.
    #
    attr_accessor :file_accessors

    # @return [Array<PBXTarget>] the resource bundle targets belonging
    #         to this target.
    attr_reader :resource_bundle_targets

    # @return [Bool] Whether or not this target should be build.
    #
    # A target should not be build if it has no source files.
    #
    def should_build?
      return @should_build if defined? @should_build
      @should_build = begin
        source_files = file_accessors.flat_map(&:source_files)
        source_files -= file_accessors.flat_map(&:headers)
        !source_files.empty?
      end
    end

    # @return [Array<Specification::Consumer>] the specification consumers for
    #         the target.
    #
    def spec_consumers
      specs.map { |spec| spec.consumer(platform) }
    end

    # @return [Boolean] Whether the target uses Swift code
    #
    def uses_swift?
      return @uses_swift if defined? @uses_swift
      @uses_swift = begin
        file_accessors.any? do |file_accessor|
          file_accessor.source_files.any? { |sf| sf.extname == '.swift' }
        end
      end
    end

    # @return [Specification] The root specification for the target.
    #
    def root_spec
      specs.first.root
    end

    # @return [String] The name of the Pod that this target refers to.
    #
    def pod_name
      root_spec.name
    end

    # @param  [String] bundle_name
    #         The name of the bundle product, which is given by the +spec+.
    #
    # @return [String] The derived name of the resource bundle target.
    #
    def resources_bundle_target_label(bundle_name)
      "#{label}-#{bundle_name}"
    end

    # @return [Array<String>] The names of the Pods on which this target
    #         depends.
    #
    def dependencies
      spec_consumers.flat_map do |consumer|
        consumer.dependencies.map { |dep| Specification.root_name(dep.name) }
      end.uniq
    end

    # @return [Array<PodTarget>] the recursive targets that this target has a
    #         dependency upon.
    #
    def recursive_dependent_targets
      targets = dependent_targets.clone

      targets.each do |target|
        target.dependent_targets.each do |t|
          targets.push(t) unless t == self || targets.include?(t)
        end
      end

      targets
    end

    # Checks if the target should be included in the build configuration with
    # the given name of a given target definition.
    #
    # @param  [TargetDefinition] target_definition
    #         The target definition to check.
    #
    # @param  [String] configuration_name
    #         The name of the build configuration.
    #
    def include_in_build_config?(target_definition, configuration_name)
      key = [target_definition.label, configuration_name]
      if @build_config_cache.key?(key)
        return @build_config_cache[key]
      end

      whitelists = target_definition_dependencies(target_definition).map do |dependency|
        target_definition.pod_whitelisted_for_configuration?(dependency.name, configuration_name)
      end.uniq

      if whitelists.empty?
        @build_config_cache[key] = true
        return true
      elsif whitelists.count == 1
        @build_config_cache[key] = whitelists.first
        whitelists.first
      else
        raise Informative, "The subspecs of `#{pod_name}` are linked to " \
          "different build configurations for the `#{target_definition}` " \
          'target. CocoaPods does not currently support subspecs across ' \
          'different build configurations.'
      end
    end

    # Checks if warnings should be inhibited for this pod.
    #
    # @return [Bool]
    #
    def inhibit_warnings?
      return @inhibit_warnings if defined? @inhibit_warnings
      whitelists = target_definitions.map do |target_definition|
        target_definition.inhibits_warnings_for_pod?(root_spec.name)
      end.uniq

      if whitelists.empty?
        @inhibit_warnings = false
        return false
      elsif whitelists.count == 1
        @inhibit_warnings = whitelists.first
        whitelists.first
      else
        UI.warn "The pod `#{pod_name}` is linked to different targets " \
          "(#{target_definitions.map(&:label)}), which contain different " \
          'settings to inhibit warnings. CocoaPods does not currently ' \
          'support different settings and will fall back to your preference ' \
          'set in the root target definition.'
        return podfile.root_target_definitions.first.inhibits_warnings_for_pod?(root_spec.name)
      end
    end

    # @param  [String] dir
    #         The directory (which might be a variable) relative to which
    #         the returned path should be. This must be used if the
    #         $CONFIGURATION_BUILD_DIR is modified.
    #
    # @return [String] The absolute path to the configuration build dir
    #
    def configuration_build_dir(dir = Generator::XCConfig::XCConfigHelper::CONFIGURATION_BUILD_DIR_VARIABLE)
      "#{dir}/#{label}"
    end

    # @param  [String] dir
    #         @see #configuration_build_dir
    #
    # @return [String] The absolute path to the build product
    #
    def build_product_path(dir = Generator::XCConfig::XCConfigHelper::CONFIGURATION_BUILD_DIR_VARIABLE)
      "#{configuration_build_dir(dir)}/#{product_name}"
    end

    # @return [String] The source path of the root for this target relative to `$(PODS_ROOT)`
    #
    def pod_target_srcroot
      "${PODS_ROOT}/#{sandbox.pod_dir(pod_name).relative_path_from(sandbox.root)}"
    end

    private

    # @param  [TargetDefinition] target_definition
    #         The target definition to check.
    #
    # @return [Array<Dependency>] The dependency of the target definition for
    #         this Pod. Return an empty array if the Pod is not a direct
    #         dependency of the target definition but the dependency of one or
    #         more Pods.
    #
    def target_definition_dependencies(target_definition)
      target_definition.dependencies.select do |dependency|
        Specification.root_name(dependency.name) == pod_name
      end
    end
  end
end
