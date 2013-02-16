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
        file_accessors.each do |fa|
          fa.path_list.read_file_system
        end
        add_source_files_references
        add_resources_references
        link_headers
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
            local = sandbox.local?(file_accessor.spec.root.name)
            parent_group = local ? pods_project.local_pods : pods_project.pods
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

      # Creates the link to the headers of the Pod in the sandbox.
      #
      # @return [void]
      #
      def link_headers
        UI.message "- Linking headers" do

          file_accessors.each do |file_accessor|
            headers_sandbox = Pathname.new(file_accessor.spec.root.name)
            sandbox.build_headers.add_search_path(headers_sandbox)
            sandbox.public_headers.add_search_path(headers_sandbox)

            consumer = file_accessor.spec_consumer
            header_mappings(headers_sandbox, consumer, file_accessor.headers, file_accessor.path_list.root).each do |namespaced_path, files|
              sandbox.build_headers.add_files(namespaced_path, files)
            end

            header_mappings(headers_sandbox, consumer, file_accessor.public_headers, file_accessor.path_list.root).each do |namespaced_path, files|
              sandbox.public_headers.add_files(namespaced_path, files)
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
      def file_accessors
        @file_accessors ||= libraries.map(&:file_accessors).flatten.compact
      end

      # Computes the destination sub-directory in the sandbox
      #
      # @param  []
      #
      # @return [Hash{Pathname => Array<Pathname>}] A hash containing the
      #         headers folders as the keys and the absolute paths of the
      #         header files as the values.
      #
      # TODO    This is being overridden in the RestKit 0.9.4 spec and that
      #         override should be fixed.
      #
      def header_mappings(headers_sandbox, consumer, headers, root)
        dir = headers_sandbox
        dir = dir + consumer.header_dir if consumer.header_dir

        mappings = {}
        headers.each do |header|
          sub_dir = dir
          if consumer.header_mappings_dir
            sub_dir = sub_dir + header.relative_path_from(consumer.header_mappings_dir).dirname
          end
          mappings[sub_dir] ||= []
          mappings[sub_dir] << header
        end
        mappings
      end

      #-----------------------------------------------------------------------#

    end
  end
end
