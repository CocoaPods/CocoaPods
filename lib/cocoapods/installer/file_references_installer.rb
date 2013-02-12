module Pod
  class Installer

    # Controller class responsible of installing the file references of the
    # specifications in the Pods project.
    #
    class FileReferencesInstaller

      # @return [Sandbox] The sandbox of the installation.
      #
      attr_reader :sandbox

      # @return [Array<Library>] The libraries of the installation.
      #
      attr_reader :libraries

      # @return [Project] The Pods project.
      #
      attr_reader :pods_project

      # @param [Sandbox] sandbox @see sandbox
      # @param [Array<Library>] libraries @see libraries
      # @param [Project] libraries @see libraries
      #
      def initialize(sandbox, libraries, pods_project)
        @sandbox = sandbox
        @libraries = libraries
        @pods_project = pods_project
      end

      # Installs the file references.
      #
      # @return [void]
      #
      def install!
        add_source_files_references
        add_resources_references
      end

      #-----------------------------------------------------------------------#

      private

      # @!group Installation Steps

      # Adds the source files of the Pods to the Pods project.
      #
      # @note   The source files are grouped by Pod and in turn by subspec
      #         (recursively).
      #
      # @note   Pods are generally added to the `Pods` group, however, if they
      #         have a local source they are added to the
      #         `Local Pods` group.
      #
      # @return [void]
      #
      def add_source_files_references
        UI.message "- Adding source files to Pods project" do
          file_accessors.each do |file_accessor|
            files = file_accessor.source_files
            spec_name = file_accessor.spec.name
            local = file_accessor.spec.local?
            parent_group = local ? pods_project.local_pods : pods_project.pods
            parent_group = pods_project.pods

            pods_project.add_file_references(files, spec_name, parent_group)
          end
        end
      end

      # Adds the resources of the Pods to the Pods project.
      #
      # @note   The source files are grouped by Pod and in turn by subspec
      #         (recursively) in the resources group.
      #
      # @return [void]
      #
      def add_resources_references
        UI.message "- Adding resources to Pods project" do
          file_accessors.each do |file_accessor|
            file_accessor.resources.each do |destination, resources|
              next if resources.empty?
              files = file_accessor.resources.values.flatten
              spec_name = file_accessor.spec.name
              parent_group = pods_project.resources

              pods_project.add_file_references(files, spec_name, parent_group)
            end
          end
        end
      end

      #-----------------------------------------------------------------------#

      private

      # @!group Private Helpers

      # @return [Array<Sandbox::FileAccessor>] The file accessors for all the
      #         specs platform combinations.
      #
      # TODO    Ideally the file accessors should be created one per spec per
      #         platform in a single installation.
      #
      def file_accessors
        @file_accessors ||= libraries.map(&:file_accessors).flatten.compact
      end

      #-----------------------------------------------------------------------#

    end
  end
end
