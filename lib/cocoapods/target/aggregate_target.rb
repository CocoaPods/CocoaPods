module Pod

  # Stores the information relative to the target used to cluster the targets
  # of the single Pods. The client targets will then depend on this one.
  #
  class AggregateTarget < Target

    # @param [TargetDefinition] target_definition @see target_definition
    # @param [Sandbox] sandbox @see sandbox
    #
    def initialize(target_definition, sandbox)
      @target_definition = target_definition
      @sandbox = sandbox
      @pod_targets = []
      @file_accessors = []
      @user_build_configurations = {}
    end

    def skip_installation?
      target_definition.empty?
    end

    # @return [String] the label for the target.
    #
    def label
      target_definition.label.to_s
    end

    #-------------------------------------------------------------------------#

    # @return [Pathname] the path of the user project that this target will
    #         integrate as identified by the analyzer.
    #
    # @note   The project instance is not stored to prevent editing different
    #         instances.
    #
    attr_accessor :user_project_path

    # @return [String] the list of the UUIDs of the user targets that will be
    #         integrated by this target as identified by the analyzer.
    #
    # @note   The target instances are not stored to prevent editing different
    #         instances.
    #
    attr_accessor :user_target_uuids




    public

    # @!group Pod targets
    #-------------------------------------------------------------------------#

    # @return [Array<PodTarget>] The dependencies for this target.
    #
    attr_accessor :pod_targets

    # @return [Array<Specification>] The specifications used by this aggregate target.
    #
    def specs
      pod_targets.map(&:specs).flatten
    end

    # @return [Array<Specification::Consumer>] The consumers of the Pod.
    #
    def spec_consumers
      specs.map { |spec| spec.consumer(platform) }
    end

    #-------------------------------------------------------------------------#

  end
end
