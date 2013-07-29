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
      @build_headers  = Sandbox::HeadersStore.new(sandbox, "BuildHeaders")
      @file_accessors = []
    end

    # @return [String] the label for the target.
    #
    def label
      "#{target_definition.label.to_s}-#{root_spec.name}"
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
      specs.map do |spec|
        spec.consumer(platform).dependencies.map { |dep| Specification.root_name(dep.name) }
      end.flatten
    end

  end
end
