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
    end

    # @return [String] the label for the target.
    #
    def label
      target_definition.label.to_s
    end

    # @return [Pathname] the folder where the client is stored used for
    #         computing the relative paths. If integrating it should be the
    #         folder where the user project is stored, otherwise it should
    #         be the installation root.
    #
    attr_accessor :client_root

    # @return [Pathname] the path of the user project that this target will
    #         integrate as identified by the analyzer.
    #
    # @note   The project instance is not stored to prevent editing different
    #         instances.
    #
    attr_accessor :user_project_path

    # @return [String] the list of the UUIDs of the user targets that will be
    #         integrated by this target as identified by the analizer.
    #
    # @note   The target instances are not stored to prevent editing different
    #         instances.
    #
    attr_accessor :user_target_uuids

    # @return [Xcodeproj::Config] The configuration file of the target.
    #
    # @note   The configuration is generated by the {TargetInstaller} and
    #         used by {UserProjectIntegrator} to check for any overridden
    #         values.
    #
    attr_accessor :xcconfig

    # @return [Array<PodTarget>] The dependencies for this target.
    #
    attr_accessor :pod_targets

    # @return [Array<SpecConsumer>]
    def spec_consumers
      pod_targets.map(&:specs).flatten.map { |spec| spec.consumer(platform) }
    end

    # @return [Pathname] The absolute path of acknowledgements file.
    #
    # @note   The acknowledgements generators add the extension according to
    #         the file type.
    #
    def acknowledgements_basepath
      support_files_root + "#{label}-acknowledgements"
    end

    # @return [Pathname] The absolute path of the copy resources script.
    #
    def copy_resources_script_path
      support_files_root + "#{label}-resources.sh"
    end

    # @return [String] The xcconfig path of the root from the `$(SRCROOT)`
    #         variable of the user's project.
    #
    def relative_pods_root
      "${SRCROOT}/#{support_files_root.relative_path_from(client_root)}"
    end

    # @return [String] The path of the xcconfig file relative to the root of
    #         the user project.
    #
    def xcconfig_relative_path
      relative_to_srcroot(xcconfig_path).to_s
    end

    # @return [String] The path of the copy resources script relative to the
    #         root of the user project.
    #
    def copy_resources_script_relative_path
      "${SRCROOT}/#{relative_to_srcroot(copy_resources_script_path)}"
    end

    #-------------------------------------------------------------------------#

    # @!group Private Helpers

    private

    # Computes the relative path of a sandboxed file from the `$(SRCROOT)`
    # variable of the user's project.
    #
    # @param  [Pathname] path
    #         A relative path from the root of the sandbox.
    #
    # @return [String] The computed path.
    #
    def relative_to_srcroot(path)
      path.relative_path_from(client_root).to_s
    end

    #-------------------------------------------------------------------------#

  end
end
