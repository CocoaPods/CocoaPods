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

    # @return [Specification::Consumer] the specification consumer for the
    #         target.
    #
    def consumer
      specs.first.root.consumer(platform)
    end

    def root_spec
      specs.first.root
    end

    #-------------------------------------------------------------------------#

  end
end
