module Xcodeproj
  class Project
    module Object
      class AbstractTarget
        # Adds a dependency on the given metadata cache.
        #
        # @param  [MetadataCache] metadata
        #         The metadata holding all the required metadata to construct itself as a target dependency.
        #
        # @return [void]
        #
        def add_cached_dependency(metadata)
          unless dependency_for_cached_target(metadata)
            container_proxy = project.new(Xcodeproj::Project::PBXContainerItemProxy)

            subproject_reference = project.reference_for_path(metadata.container_project_path)
            raise ArgumentError, "add_dependency received target (#{target}) that belongs to a project that is not this project (#{self}) and is not a subproject of this project" unless subproject_reference
            container_proxy.container_portal = subproject_reference.uuid

            container_proxy.proxy_type = Constants::PROXY_TYPES[:native_target]
            container_proxy.remote_global_id_string = metadata.native_target_uuid
            container_proxy.remote_info = metadata.target_label

            dependency = project.new(Xcodeproj::Project::PBXTargetDependency)
            dependency.name = metadata.target_label
            dependency.target_proxy = container_proxy

            dependencies << dependency
          end
        end

        # Checks whether this target has a dependency on the given target.
        #
        # @param  [TargetMetadata] cached_target
        #         the target to search for.
        #
        # @return [PBXTargetDependency]
        #
        def dependency_for_cached_target(cached_target)
          dependencies.find do |dep|
            if dep.target_proxy.remote?
              subproject_reference = project.reference_for_path(cached_target.container_project_path)
              uuid = subproject_reference.uuid if subproject_reference
              dep.target_proxy.remote_global_id_string == cached_target.native_target_uuid && dep.target_proxy.container_portal == uuid
            else
              dep.target.uuid == cached_target.native_target_uuid
            end
          end
        end
      end
    end
  end
end
