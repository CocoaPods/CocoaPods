module Pod

  class Podfile
    def config
      UI.warn "Podfile#config is deprecated. The config is accessible from " \
        "the parameter passed to the hooks"
      Config.instance
    end
  end

  # The public API should return dumb data types so it is easier to satisfy its
  # implicit contract.
  #
  module Hooks

    # Stores the information of the Installer for the hooks
    #
    class InstallerData

      public

      # @!group Public Hooks API

      # @return [Pathname] The root of the sandbox.
      #
      def sandbox_root
        installer.sandbox.root
      end

      # @return [Pod::Project] the `Pods/Pods.xcodeproj` project.
      #
      def project
        installer.pods_project
      end

      # @return [Array<PodData>] The list of LocalPod instances for each
      #         dependency sorted by name.
      #
      def pods
        installer.pods_data
      end

      # @return [Array<TargetInstallerData>]
      #
      def target_installers
        installer.target_installers_data
      end

      # @return [Hash{TargetDefinition => Array<Specification>}] The
      #         specifications grouped by target definition.
      #
      # @todo   Consider grouping by TargetInstallerData.
      #
      def specs_by_target
        result = {}
        libraries.each do |lib|
          result[lib.target_definition] = lib.specs
        end
        result
      end

      # @return [Hash{TargetDefinition => Array<LocalPod>}] The local pod
      #         instances grouped by target.
      #
      def pods_by_target
        result = {}
        libraries.each do |lib|
          root_specs = lib.specs.map { |spec| spec.root }.uniq
          pods_data = pods.select { |pod_data| root_specs.include?(pod_data.root_spec) }
          result[lib.target_definition] = pods_data
        end
        result
      end

      # @see   pods_by_target
      #
      # @todo Fix the warning.
      #
      def local_pods_by_target
        # UI.warn "Podfile#config is deprecated. The config is accessible from " \
        #   "the parameter passed to the hooks".
        pods_by_target
      end



      #-----------------------------------------------------------------------#

      public

      # @!group Unsafe Hooks API
      #
      # The interface of the following objects might change at any time.
      # If there some information which is needed, please open an issue.

      # @return [Sandbox] sandbox the sandbox where the support files should
      #         be generated.
      #
      def sandbox
        installer.sandbox
      end

      # @return [Config] The config singleton used for the installation.
      #
      def config
        Config.instance
      end

      #-----------------------------------------------------------------------#

      # @!group Private implementation

      # @param [Installer] installer @see installer
      #
      def initialize(installer)
        @installer = installer
      end

      private

      # @return [Installer] The installer described by this instance.
      #
      attr_reader :installer

      # @return [Library] The library whose target needs to be generated.
      #
      def libraries
        installer.libraries
      end

      #-----------------------------------------------------------------------#

    end
  end
end


