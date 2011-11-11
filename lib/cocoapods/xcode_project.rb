require 'xcodeproj'

module Xcode
  class Project
    # Shortcut access to the `Pods' PBXGroup.
    def pods
      groups.find { |g| g.name == 'Pods' } || groups.new({ 'name' => 'Pods' })
    end

    # Adds a group as child to the `Pods' group.
    def add_pod_group(name)
      pods.groups.new('name' => name)
    end
    
    class PBXCopyFilesBuildPhase
      def self.new_pod_dir(project, pod_name, path)
        new(project, nil, {
            "dstPath" => "$(PUBLIC_HEADERS_FOLDER_PATH)/#{path}",
            "name"    => "Copy #{pod_name} Public Headers",
          })
      end
    end
  end
end
