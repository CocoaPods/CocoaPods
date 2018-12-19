module Pod
  class Installer
    class ProjectCache
      # Metadata used to reconstruct a PBXTargetDependency.
      #
      class TargetMetadata
        # @return [String]
        #         The label of the native target.
        #
        attr_reader :target_label

        # @return [String]
        #         The UUID of the native target installed.
        #
        attr_reader :native_target_uuid

        # @return [String]
        #         The path of the container project the native target was installed into.
        #
        attr_reader :container_project_path

        # Initialize a new instance.
        #
        # @param [String] target_label @see #target_label
        # @param [String] native_target_uuid @see #native_target_uuid
        # @param [String] container_project_path @see #container_project_path
        #
        def initialize(target_label, native_target_uuid, container_project_path)
          @target_label = target_label
          @native_target_uuid = native_target_uuid
          @container_project_path = container_project_path
        end

        def to_hash
          {
              'LABEL' => target_label,
              'UUID' => native_target_uuid,
              'PROJECT_PATH' => container_project_path
          }
        end

        def to_s
          "#{target_label} : #{native_target_uuid} : #{container_project_path}"
        end

        # @return [TargetMetadata]
        #
        # @param [Hash] hash
        #        The hash used to construct a new TargetMetadata instance.
        #
        def self.cache_metadata_from_hash(hash)
          TargetMetadata.new(hash['LABEL'], hash['UUID'], hash['PROJECT_PATH'])
        end

        # @return [TargetMetadata]
        #
        # @param [PBXNativeTarget] native_target
        #        The native target used to construct a TargetMetadata instance.
        def self.cache_metadata_from_native_target(native_target)
          TargetMetadata.new(native_target.name, native_target.uuid, native_target.project.path.to_s)
        end
      end
    end
  end
end
