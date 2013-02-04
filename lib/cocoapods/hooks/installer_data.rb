module Pod
  module Hooks

    # Stores the information of the Installer for the hooks
    #
    class InstallerData

      include Config::Mixin

      # @return [Sandbox] sandbox the sandbox where the support files should
      #         be generated.
      #
      attr_accessor :sandbox

      # @return [Library] The library whose target needs to be generated.
      #
      attr_accessor :libraries

      # @return [Array<TargetInstaller>]
      #
      # attr_accessor :target_installers

      # @return [Hash{TargetDefinition => Array<LocalPod>}] The local pod
      #         instances grouped by target.
      #
      # attr_accessor :local_pods_by_target

      # @return [Array<PodData>] The list of LocalPod instances for each
      #         dependency sorted by name.
      #
      attr_accessor :pods

      # @return [Pod::Project] the `Pods/Pods.xcodeproj` project.
      #
      attr_accessor :project

    end
  end
end




