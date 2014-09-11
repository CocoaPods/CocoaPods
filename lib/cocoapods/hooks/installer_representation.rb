module Pod
  # @todo: Remove by CocoaPods 1.0
  #
  class Podfile
    def config
      UI.warn 'Podfile#config is deprecated. The config is accessible from ' \
        'the parameter passed to the hooks'
      Config.instance
    end

    class TargetDefinition
      def copy_resources_script_name
        UI.warn 'TargetDefinition#copy_resources_script_name is deprecated. ' \
          'The value is accessible directly from the representation of the ' \
          'library using the #copy_resources_script_path method.'
        Config.instance.sandbox.root + "#{label}-resources.sh"
      end
    end
  end

  module Hooks
    # The installer representation to pass to the hooks.
    #
    class InstallerRepresentation
      public

      # @!group Public Hooks API

      # @return [Pathname] The root of the sandbox.
      #
      def sandbox_root
        installer.sandbox.root
      end

      # @return [Pod::Project] the `Pods/Pods.xcodeproj` project.
      #
      # @note   This value is not yet set in the pre install callbacks.
      #
      def project
        installer.pods_project
      end

      # @return [Array<PodRepresentation>] The representation of the Pods.
      #
      def pods
        installer.pod_reps
      end

      # @return [Array<LibraryRepresentation>] The representation of the
      #         libraries.
      #
      def libraries
        installer.library_reps
      end

      # @return [Hash{LibraryRepresentation => Array<Specification>}] The
      #         specifications grouped by target definition.
      #
      def specs_by_lib
        result = {}
        installer.aggregate_targets.each do |aggregate_target|
          result[installer.library_rep(aggregate_target)] = aggregate_target.specs
        end
        result
      end

      # @return [Hash{LibraryRepresentation => Array<PodRepresentation>}] The
      #         local pod instances grouped by target.
      #
      def pods_by_lib
        result = {}
        installer.aggregate_targets.map(&:pod_targets).flatten.each do |lib|
          pod_names = [lib.root_spec.name]
          pod_reps = pods.select { |rep| pod_names.include?(rep.name) }
          result[lib.target_definition] = pod_reps
        end
        result
      end

      #-----------------------------------------------------------------------#

      public

      # @!group Compatibility
      #
      # The following aliases provides compatibility with CP < 0.17

      alias_method :target_installers, :libraries
      alias_method :specs_by_target, :specs_by_lib
      alias_method :local_pods_by_target, :pods_by_lib

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

      # @return [Installer] The installer described by this instance.
      #
      attr_reader :installer

      #-----------------------------------------------------------------------#

      # @!group Private implementation

      # @param [Installer] installer @see installer
      #
      def initialize(installer)
        @installer = installer
      end

      #-----------------------------------------------------------------------#
    end
  end
end
