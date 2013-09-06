module Pod
  class Installer
    class PodsProjectGenerator

      # Controller class responsible of installing the file references of the
      # specifications in the Pods project.
      #
      class FileReferencesInstaller

        # @return [Sandbox] The sandbox of the installation.
        #
        attr_reader :sandbox

        # @return [Array<Library>] The libraries of the installation.
        #
        attr_reader :pod_targets

        # @param [Sandbox] sandbox @see sandbox
        # @param [Array<Library>] libraries @see libraries
        # @param [Project] libraries @see libraries
        #
        def initialize(sandbox, pod_targets)
          @sandbox = sandbox
          @pod_targets = pod_targets
        end

        # Installs the file references.
        #
        # @return [void]
        #
        def install!
          refresh_file_accessors
          add_source_files_references
          add_frameworks_bundles
          add_vendored_libraries
          add_resources
        end


        private

        # @!group Installation Steps
        #---------------------------------------------------------------------#

        # Reads the file accessors contents from the file system.
        #
        # @note   The contents of the file accessors are modified by the clean
        #         step of the #{PodSourceInstaller} and by the pre install hooks.
        #
        # @return [void]
        #
        def refresh_file_accessors
          file_accessors.each do |fa|
            fa.path_list.read_file_system
          end
        end

        # Adds the source files of the Pods to the Pods project.
        #
        # @note   The source files are grouped by Pod and in turn by subspec
        #         (recursively).
        #
        # @return [void]
        #
        def add_source_files_references
          UI.message "- Adding source files" do
            add_paths_to_group(:source_files, :source_files)
          end
        end

        # Adds the bundled frameworks to the Pods project
        #
        # @return [void]
        #
        def add_frameworks_bundles
          UI.message "- Adding frameworks" do
            add_paths_to_group(:vendored_frameworks, :frameworks_and_libraries)
          end
        end

        # Adds the bundled libraries to the Pods project
        #
        # @return [void]
        #
        def add_vendored_libraries
          UI.message "- Adding libraries" do
            add_paths_to_group(:vendored_libraries, :frameworks_and_libraries)
          end
        end

        # Adds the resources of the Pods to the Pods project.
        #
        # @note   The source files are grouped by Pod and in turn by subspec
        #         (recursively) in the resources group.
        #
        # @return [void]
        #
        def add_resources
          UI.message "- Adding resources" do
            add_paths_to_group(:resources, :resources)
            add_paths_to_group(:resource_bundle_files, :resources)
          end
        end


        private

        # @!group Private Helpers
        #---------------------------------------------------------------------#


        # @return [Array<Sandbox::FileAccessor>] The file accessors for all the
        #         specs platform combinations.
        #
        def file_accessors
          @file_accessors ||= pod_targets.map(&:file_accessors).flatten.compact
        end

        # Adds file references to the list of the paths returned by the file
        # accessor with the given key to the given group of the Pods project.
        #
        # @param  [Symbol] file_accessor_key
        #         The method of the file accessor which would return the list of
        #         the paths.
        #
        # @param  [Symbol] group_key
        #         The key of the group of the Pods project.
        #
        # @return [void]
        #
        def add_paths_to_group(file_accessor_key, group_key)
          file_accessors.each do |file_accessor|
            paths = file_accessor.send(file_accessor_key)
            paths.each do |path|
              group = sandbox.project.group_for_spec(file_accessor.spec.name, group_key)
              sandbox.project.add_file_reference(path, group)
            end
          end
        end

        #---------------------------------------------------------------------#

      end
    end
  end
end
