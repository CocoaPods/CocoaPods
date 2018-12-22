module Pod
  class Installer
    # Generates stable UUIDs for Native Targets.
    #
    class TargetUUIDGenerator < Xcodeproj::Project::UUIDGenerator
      # This method override is used to ONLY generate stable UUIDs for PBXNativeTarget instances and no other type.
      # Stable native target UUIDs are necessary for incremental installation because other projects reference the
      # target by its UUID in the remoteGlobalIDString field.
      #
      def generate_all_paths_by_objects(projects)
        @paths_by_object = {}
        all_objects = projects.flat_map(&:objects)
        all_objects.each do |object|
          @paths_by_object[object] = if object.is_a? Xcodeproj::Project::Object::AbstractTarget
                                       project_basename = object.project.path.basename.to_s
                                       Digest::MD5.hexdigest(project_basename + object.name).upcase
                                     else
                                       object.uuid
                                     end
        end
      end

      def uuid_for_path(path)
        path
      end
    end
  end
end
