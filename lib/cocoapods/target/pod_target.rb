module Pod
  # Stores the information relative to the target used to compile a single Pod.
  # A pod can have one or more activated spec/subspecs.
  #
  class PodTarget < Target
    # @return [Array<Specification>] the spec and subspecs for the target.
    #
    attr_reader :specs

    # @return [HeadersStore] the header directory for the target.
    #
    attr_reader :build_headers

    # @return [Bool] whether the target needs to be scoped by target definition,
    #         because the spec is used with different subspec sets across them.
    #
    attr_accessor :scoped
    alias_method :scoped?, :scoped

    # @param [Specification] spec @see spec
    # @param [TargetDefinition] target_definition @see target_definition
    # @param [Sandbox] sandbox @see sandbox
    #
    def initialize(specs, target_definition, sandbox)
      @specs = specs
      @target_definition = target_definition
      @sandbox = sandbox
      @build_headers  = Sandbox::HeadersStore.new(sandbox, 'Private')
      @file_accessors = []
      @resource_bundle_targets = []
    end

    # @return [PodTarget] the same target, but scoped.
    #
    def scoped
      clone.tap do |scoped_target|
        scoped_target.scoped = true
      end
    end

    # @return [String] the label for the target.
    #
    def label
      if scoped?
        "#{target_definition.label}-#{root_spec.name}"
      else
        root_spec.name
      end
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
      source_files = file_accessors.flat_map(&:source_files)
      source_files -= file_accessors.flat_map(&:headers)
      !source_files.empty?
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
      file_accessors.any? do |file_accessor|
        file_accessor.source_files.any? { |sf| sf.extname == '.swift' }
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
      spec_consumers.map do |consumer|
        consumer.dependencies.map { |dep| Specification.root_name(dep.name) }
      end.flatten
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
      whitelists = target_definition_dependencies(target_definition).map do |dependency|
        target_definition.pod_whitelisted_for_configuration?(dependency.name, configuration_name)
      end.uniq

      if whitelists.empty?
        return true
      elsif whitelists.count == 1
        whitelists.first
      else
        raise Informative, "The subspecs of `#{pod_name}` are linked to " \
          "different build configurations for the `#{target_definition}` " \
          'target. CocoaPods does not currently support subspecs across ' \
          'different build configurations.'
      end
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
