require 'xcodeproj/project'
require 'xcodeproj/project/object/build_phase'

Xcodeproj::Project::Object::PBXCopyFilesBuildPhase.instance_eval do
  def self.new_pod_dir(project, pod_name, path)
    new(project, nil, {
      "dstPath" => "Pods/#{path}",
      "name"    => "Copy #{pod_name} Public Headers",
    })
  end
end

module Pod
  class Project < Xcodeproj::Project
    def initialize(*)
      super
      main_group << groups.new('name' => 'Pods')
    end

    # Shortcut access to the `Pods' PBXGroup.
    def pods
      groups.find { |g| g.name == 'Pods' } || groups.new({ 'name' => 'Pods' })
    end

    # Adds a group as child to the `Pods' group.
    def add_pod_group(name)
      pods.groups.new('name' => name)
    end

    def add_pod_target(name, platform)
      target = targets.new_static_library(platform.name, name)

      settings = {}
      if platform.requires_legacy_ios_archs?
        settings['ARCHS'] = "armv6 armv7"
      end
      if platform == :ios && platform.deployment_target
        settings['IPHONEOS_DEPLOYMENT_TARGET'] = platform.deployment_target.to_s
      end

      target.build_settings('Debug').merge!(settings)
      target.build_settings('Release').merge!(settings)

      target
    end
  end
end
