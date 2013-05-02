module Pod
  class Installer
    class Analyzer

      # Analyze the sandbox to detect which Pods should be removed, and which
      # ones should be reinstalled.
      #
      # The logic is the following:
      #
      # Added
      # - If not present in the sandbox lockfile.
      # - The directory of the Pod doesn't exits.
      #
      # Changed
      # - The version of the Pod changed.
      # - The SHA of the specification file changed.
      # - The specific installed (sub)specs of the same Pod changed.
      # - The specification is in head mode or from an external source and the
      #   installation process is in update mode.
      # - The directory of the Pod is empty.
      # - The Pod has been pre-downloaded.
      #
      # Removed
      # - If a specification is present in the lockfile but not in the resolved
      #   specs.
      #
      # Unchanged
      # - If none of the above conditions match.
      #
      class SandboxAnalyzer

        # @return [Sandbox] The sandbox to analyze.
        #
        attr_reader :sandbox

        # @return [Array<Specifications>] The specifications returned by the
        #         resolver.
        #
        attr_reader :specs

        # @return [Bool] Whether the installation is performed in update mode.
        #
        attr_reader :update_mode

        # @return [Lockfile] The lockfile of the installation as a fall-back if
        #         there is no sandbox manifest. This is indented as a temporary
        #         solution to prevent the full re-installation from users which
        #         are upgrading from CP < 0.17.
        #
        # @todo   Remove for CP 0.18.
        #
        attr_reader :lockfile

        # @param [Sandbox] sandbox @see sandbox
        # @param [Array<Specifications>] specs @see specs
        # @param [Bool] update_mode @see update_mode
        # @param [Lockfile] lockfile @see lockfile
        #
        def initialize(sandbox, specs, update_mode, lockfile = nil)
          @sandbox = sandbox
          @specs = specs
          @update_mode = update_mode
          @lockfile = lockfile
        end

        # Performs the analysis to the detect the state of the sandbox respect
        # to the resolved specifications.
        #
        # @return [SpecsState] the state of the sandbox.
        #
        def analyze
          state = SpecsState.new
          if sandbox_manifest
            all_names = (resolved_pods + sandbox_pods).uniq.sort
            all_names.sort.each do |name|
              state.add_name(name, pod_state(name))
            end
          else
            state.added.concat(resolved_pods)
          end
          state
        end

        #---------------------------------------------------------------------#

        private

        # @!group Pod state

        # Returns the state of the Pod with the given name.
        #
        # @param  [String] pod
        #         the name of the Pod.
        #
        # @return [Symbol] The state
        #
        def pod_state(pod)
          return :added   if pod_added?(pod)
          return :deleted if pod_deleted?(pod)
          return :changed if pod_changed?(pod)
          return :unchanged
        end

        # Returns whether the Pod with the given name should be installed.
        #
        # @note   A Pod whose folder doesn't exists is considered added.
        #
        # @param  [String] pod
        #         the name of the Pod.
        #
        # @return [Bool] Whether the Pod is added.
        #
        def pod_added?(pod)
          return true if resolved_pods.include?(pod) && !sandbox_pods.include?(pod)
          return true if !folder_exist?(pod)
          return false
        end

        # Returns whether the Pod with the given name should be removed from
        # the installation.
        #
        # @param  [String] pod
        #         the name of the Pod.
        #
        # @return [Bool] Whether the Pod is deleted.
        #
        def pod_deleted?(pod)
          return true if !resolved_pods.include?(pod) && sandbox_pods.include?(pod)
          return false
        end

        # Returns whether the Pod with the given name should be considered
        # changed and thus should be reinstalled.
        #
        # @note   In update mode, as there is no way to know if a remote source
        #         hash changed the Pods in head mode and the ones from external
        #         sources are always marked as changed.
        #
        # @note   A Pod whose folder is empty is considered changed.
        #
        # @param  [String] pod
        #         the name of the Pod.
        #
        # @return [Bool] Whether the Pod is changed.
        #
        def pod_changed?(pod)
          spec = root_spec(pod)
          return true if spec.version != sandbox_version(pod)
          return true if spec.checksum != sandbox_checksum(pod)
          return true if resolved_spec_names(pod) != sandbox_spec_names(pod)
          return true if sandbox.predownloaded?(pod)
          return true if folder_empty?(pod)
          if update_mode
            return true if spec.version.head?
          end
          return false
        end

        #---------------------------------------------------------------------#

        private

        # @!group Private helpers

        # @return [Lockfile] The manifest to use for the sandbox.
        #
        def sandbox_manifest
          sandbox.manifest || lockfile
        end

        #--------------------------------------#

        # @return [Array<String>] The name of the resolved Pods.
        #
        def resolved_pods
          specs.map { |spec| spec.root.name }.uniq
        end

        # @return [Array<String>] The name of the Pods stored in the sandbox
        #         manifest.
        #
        def sandbox_pods
          sandbox_manifest.pod_names.map { |name| Specification.root_name(name) }.uniq
        end

        # @return [Array<String>] The name of the resolved specifications
        #         (includes subspecs).
        #
        # @param  [String] pod
        #         the name of the Pod.
        #
        def resolved_spec_names(pod)
          specs.select { |s| s.root.name == pod }.map(&:name).uniq.sort
        end

        # @return [Array<String>] The name of the specifications stored in the
        #         sandbox manifest (includes subspecs).
        #
        # @param  [String] pod
        #         the name of the Pod.
        #
        def sandbox_spec_names(pod)
          sandbox_manifest.pod_names.select { |name| Specification.root_name(name) == pod }.uniq.sort
        end

        # @return [Specification] The root specification for the Pod with the
        #         given name.
        #
        # @param  [String] pod
        #         the name of the Pod.
        #
        def root_spec(pod)
          specs.find { |s| s.root.name == pod }.root
        end

        #--------------------------------------#

        # @return [Version] The version of Pod with the given name stored in
        #         the sandbox.
        #
        # @param  [String] pod
        #         the name of the Pod.
        #
        def sandbox_version(pod)
          sandbox_manifest.version(pod)
        end

        # @return [String] The checksum of the specification of the Pod with
        #         the given name stored in the sandbox.
        #
        # @param  [String] pod
        #         the name of the Pod.
        #
        def sandbox_checksum(pod)
          sandbox_manifest.checksum(pod)
        end

        #--------------------------------------#

        def folder_exist?(pod)
          sandbox.pod_dir(pod).exist?
        end

        def folder_empty?(pod)
          Dir.glob(sandbox.pod_dir(pod) + '*').empty?
        end

        #---------------------------------------------------------------------#

      end
    end
  end
end
