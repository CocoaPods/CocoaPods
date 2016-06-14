module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        # Controller class responsible of installing the file references of the
        # specifications in the Pods project.
        #
        class FileReferencesInstaller
          # @return [Sandbox] The sandbox of the installation.
          #
          attr_reader :sandbox

          # @return [Array<PodTarget>] The pod targets of the installation.
          #
          attr_reader :pod_targets

          # @return [Project] The Pods project.
          #
          attr_reader :pods_project

          # Initialize a new instance
          #
          # @param [Sandbox] sandbox @see sandbox
          # @param [Array<PodTarget>] pod_targets @see pod_targets
          # @param [Project] pods_project @see pod_project
          #
          def initialize(sandbox, pod_targets, pods_project)
            @sandbox = sandbox
            @pod_targets = pod_targets
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
              add_file_accessors_paths_to_pods_group(:source_files, nil, true)
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
              add_file_accessors_paths_to_pods_group(:resources, :resources, true)
              add_file_accessors_paths_to_pods_group(:resource_bundle_files, :resources, true)
            end
          end

          # Creates the link to the headers of the Pod in the sandbox.
          #
          # @return [void]
          #
          def link_headers
            UI.message '- Linking headers' do
              pod_targets.each do |pod_target|
                pod_target.file_accessors.each do |file_accessor|
                  framework_exp = /\.framework\//
                  headers_sandbox = Pathname.new(file_accessor.spec.root.name)

                  # When integrating Pod as frameworks, built Pods are built into
                  # frameworks, whose headers are included inside the built
                  # framework. Those headers do not need to be linked from the
                  # sandbox.
                  unless pod_target.requires_frameworks? && pod_target.should_build?
                    pod_target.build_headers.add_search_path(headers_sandbox, pod_target.platform)
                    sandbox.public_headers.add_search_path(headers_sandbox, pod_target.platform)

                    header_mappings(headers_sandbox, file_accessor, file_accessor.headers).each do |namespaced_path, files|
                      pod_target.build_headers.add_files(namespaced_path, files.reject { |f| f.to_path =~ framework_exp })
                    end

                    header_mappings(headers_sandbox, file_accessor, file_accessor.public_headers).each do |namespaced_path, files|
                      sandbox.public_headers.add_files(namespaced_path, files.reject { |f| f.to_path =~ framework_exp })
                    end
                  end

                  unless pod_target.requires_frameworks?
                    vendored_frameworks_header_mappings(headers_sandbox, file_accessor).each do |namespaced_path, files|
                      sandbox.public_headers.add_files(namespaced_path, files)
                    end
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
          # @param  [Bool] reflect_file_system_structure_for_development
          #         Whether organizing a local pod's files in subgroups inside
          #         the pod's group is allowed.
          #
          # @return [void]
          #
          def add_file_accessors_paths_to_pods_group(file_accessor_key, group_key = nil, reflect_file_system_structure_for_development = false)
            file_accessors.each do |file_accessor|
              pod_name = file_accessor.spec.name
              local = sandbox.local?(pod_name)
              paths = file_accessor.send(file_accessor_key)
              paths = allowable_project_paths(paths)
              paths.each do |path|
                group = pods_project.group_for_spec(file_accessor.spec.name, group_key)
                pods_project.add_file_reference(path, group, local && reflect_file_system_structure_for_development)
              end
            end
          end

          # Filters a list of paths down to those paths which can be added to
          # the Xcode project. Some paths are intermediates and only their children
          # should be added, while some paths are treated as bundles and their
          # children should not be added directly.
          #
          # @param  [Array<Pathname>] paths
          #         The paths to files or directories on disk.
          #
          # @return [Array<Pathname>] The paths which can be added to the Xcode project
          #
          def allowable_project_paths(paths)
            lproj_paths = Set.new
            lproj_paths_with_files = Set.new
            allowable_paths = paths.select do |path|
              path_str = path.to_s

              # We add the directory for a Core Data model, but not the items in it.
              next if path_str =~ /.*\.xcdatamodeld\/.+/i

              # We add the directory for a Core Data migration mapping, but not the items in it.
              next if path_str =~ /.*\.xcmappingmodel\/.+/i

              # We add the directory for an asset catalog, but not the items in it.
              next if path_str =~ /.*\.xcassets\/.+/i

              if path_str =~ /\.lproj(\/|$)/i
                # If the element is an .lproj directory then save it and potentially
                # add it later if we don't find any contained items.
                if path_str =~ /\.lproj$/i && path.directory?
                  lproj_paths << path
                  next
                end

                # Collect the paths for the .lproj directories that contain files.
                lproj_path = /(^.*\.lproj)\/.*/i.match(path_str)[1]
                lproj_paths_with_files << Pathname(lproj_path)

                # Directories nested within an .lproj directory are added as file
                # system references so their contained items are not added directly.
                next if path.dirname.dirname == lproj_path
              end

              true
            end

            # Only add the path for the .lproj directories that do not have anything
            # within them added as well. This generally happens if the glob within the
            # resources directory was not a recursive glob.
            allowable_paths + lproj_paths.subtract(lproj_paths_with_files).to_a
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

          # Computes the destination sub-directory in the sandbox for headers
          # from inside vendored frameworks.
          #
          # @param  [Pathname] headers_sandbox
          #         The sandbox where the header links should be stored for this
          #         Pod.
          #
          # @param  [Sandbox::FileAccessor] file_accessor
          #         The consumer file accessor for which the headers need to be
          #         linked.
          #
          def vendored_frameworks_header_mappings(headers_sandbox, file_accessor)
            mappings = {}
            file_accessor.vendored_frameworks.each do |framework|
              headers_dir = Sandbox::FileAccessor.vendored_frameworks_headers_dir(framework)
              headers = Sandbox::FileAccessor.vendored_frameworks_headers(framework)
              framework_name = framework.basename(framework.extname)
              dir = headers_sandbox + framework_name
              headers.each do |header|
                # the relative path of framework headers should be kept,
                # not flattened like is done for most public headers.
                relative_path = header.relative_path_from(headers_dir)
                sub_dir = dir + relative_path.dirname
                mappings[sub_dir] ||= []
                mappings[sub_dir] << header
              end
            end
            mappings
          end

          #-----------------------------------------------------------------------#
        end
      end
    end
  end
end
