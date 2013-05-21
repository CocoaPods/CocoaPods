module Pod

  # This target is used to compile a single Pod. A pod can have one or more
  # activated spec/subspecs.
  #
  class PodTarget < Target

    # @return [Specification] the spec for the target.
    #
    attr_reader :spec

    # @return [HeadersStore] the header directory for the library.
    #
    attr_reader :build_headers

    # @param [Specification] spec @see spec
    # @param [TargetDefinition] target_definition @see target_definition
    # @param [Sandbox] sandbox @see sandbox
    #
    def initialize(spec, target_definition, sandbox)
      @spec = spec
      @target_definition = target_definition
      @sandbox = sandbox
      @build_headers  = Sandbox::HeadersStore.new(sandbox, "BuildHeaders")
      @file_accessors = []
    end

    # @return [String] the label for the library.
    #
    def label
      "#{target_definition.label.to_s}-#{spec.name.gsub('/', '-')}"
    end

    # @return [Specification] the specification for this library.
    #
    attr_accessor :spec

    # @return [Array<Sandbox::FileAccessor>] the file accessors for the
    #         specifications of this library.
    #
    attr_accessor :file_accessors

    #-------------------------------------------------------------------------#

    # @return [Specification::Consumer] the specification consumer for the
    #         library.
    #
    def consumer
      spec.consumer(platform)
    end

    #-------------------------------------------------------------------------#

  end
end
