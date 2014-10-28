module Pod
  class Installer
    # Controller class responsible of installing the file references of the
    # specifications in the Pods project.
    #
    class FileReferencesInstaller
      # @return [Sandbox] The sandbox of the installation.
      #
      attr_reader :sandbox

      # @return [Array<PodTarget>] The libraries of the installation.
      #
      attr_reader :libraries

      # @return [Project] The Pods project.
      #
      attr_reader :pods_project

      # @param [Sandbox] sandbox @see sandbox
      # @param [Array<PodTarget>] libraries @see libraries
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
        refresh_file_accessors
        add_source_files_references
        add_frameworks_bundles
        add_vendored_libraries
        add_resources
        link_headers
      end

      #-----------------------------------------------------------------------#

      private

      # @!group Installation Steps

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
        UI.message '- Adding source files to Pods project' do
          add_file_accessors_paths_to_pods_group(:source_files)
        end
      end

      # Adds the bundled frameworks to the Pods project
      #
      # @return [void]
      #
      def add_frameworks_bundles
        UI.message '- Adding frameworks to Pods project' do
          add_file_accessors_paths_to_pods_group(:vendored_frameworks, :frameworks)
        end
      end

      # Adds the bundled libraries to the Pods project
      #
      # @return [void]
      #
      def add_vendored_libraries
        UI.message '- Adding libraries to Pods project' do
          add_file_accessors_paths_to_pods_group(:vendored_libraries, :frameworks)
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
        UI.message '- Adding resources to Pods project' do
          add_file_accessors_paths_to_pods_group(:resources, :resources)
          add_file_accessors_paths_to_pods_group(:resource_bundle_files, :resources)
        end
      end

      # Creates the link to the headers of the Pod in the sandbox.
      #
      # @return [void]
      #
      def link_headers
        UI.message '- Linking headers' do
          libraries.each do |library|
            library.file_accessors.each do |file_accessor|
              headers_sandbox = Pathname.new(file_accessor.spec.root.name)
              library.build_headers.add_search_path(headers_sandbox, library.platform)
              sandbox.public_headers.add_search_path(headers_sandbox, library.platform)

              header_mappings(headers_sandbox, file_accessor, file_accessor.headers).each do |namespaced_path, files|
                library.build_headers.add_files(namespaced_path, files, library.platform)
              end

              header_mappings(headers_sandbox, file_accessor, file_accessor.public_headers).each do |namespaced_path, files|
                sandbox.public_headers.add_files(namespaced_path, files, library.platform)
              end
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
      def add_file_accessors_paths_to_pods_group(file_accessor_key, group_key = nil)
        file_accessors.each do |file_accessor|
          paths = file_accessor.send(file_accessor_key)
          paths.each do |path|
            group = pods_project.group_for_spec(file_accessor.spec.name, group_key)
            pods_project.add_file_reference(path, group)
          end
        end
      end

      # Computes the destination sub-directory in the sandbox
      #
      # @param  [Pathname] headers_sandbox
      #         The sandbox where the header links should be stored for this
      #         Pod.
      #
      # @param  [Sandbox::FileAccessor] file_accessor
      #         The consumer file accessor for which the headers need to be
      #         linked.
      #
      # @param  [Array<Pathname>] headers
      #         The absolute paths of the headers which need to be mapped.
      #
      # @return [Hash{Pathname => Array<Pathname>}] A hash containing the
      #         headers folders as the keys and the absolute paths of the
      #         header files as the values.
      #
      def header_mappings(headers_sandbox, file_accessor, headers)
        consumer = file_accessor.spec_consumer
        dir = headers_sandbox
        dir += consumer.header_dir if consumer.header_dir

        mappings = {}
        headers.each do |header|
          sub_dir = dir
          if consumer.header_mappings_dir
            header_mappings_dir = file_accessor.path_list.root + consumer.header_mappings_dir
            relative_path = header.relative_path_from(header_mappings_dir)
            sub_dir += relative_path.dirname
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
