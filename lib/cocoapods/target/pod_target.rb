module Pod
  # Stores the information relative to the target used to compile a single Pod.
  # A pod can have one or more activated spec/subspecs.
  #
  class PodTarget < Target
    # @return [Specification] the spec for the target.
    #
    attr_reader :specs

    # @return [HeadersStore] the header directory for the target.
    #
    attr_reader :build_headers

    # @param [Specification] spec @see spec
    # @param [TargetDefinition] target_definition @see target_definition
    # @param [Sandbox] sandbox @see sandbox
    #
    def initialize(specs, target_definition, sandbox)
      @specs = specs
      @target_definition = target_definition
      @sandbox = sandbox
      @build_headers  = Sandbox::HeadersStore.new(sandbox, 'Build')
      @file_accessors = []
    end

    # @return [String] the label for the target.
    #
    def label
      "#{target_definition.label}-#{root_spec.name}"
    end

    # @return [Array<Sandbox::FileAccessor>] the file accessors for the
    #         specifications of this target.
    #
    attr_accessor :file_accessors

    # @return [Array<Specification::Consumer>] the specification consumers for
    #         the target.
    #
    def spec_consumers
      specs.map { |spec| spec.consumer(platform) }
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

    # @return [Array<String>] The names of the Pods on which this target
    #         depends.
    #
    def dependencies
      spec_consumers.map do |consumer|
        consumer.dependencies.map { |dep| Specification.root_name(dep.name) }
      end.flatten
    end

    # Checks if the target should be included in the build configuration with
    # the given name.
    #
    # @param  [String] configuration_name
    #         The name of the build configuration.
    #
    def include_in_build_config?(configuration_name)
      whitelists = target_definition_dependencies.map do |dependency|
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

    # @return [Array<Dependency>] The dependency of the target definition for
    #         this Pod. Return an empty array if the Pod is not a direct
    #         dependency of the target definition but the dependency of one or
    #         more Pods.
    #
    def target_definition_dependencies
      target_definition.dependencies.select do |dependency|
        Specification.root_name(dependency.name) == pod_name
      end
    end
  end
end
