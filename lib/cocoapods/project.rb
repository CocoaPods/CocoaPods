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
      @user_build_configurations = []
    end

    def user_build_configurations=(user_build_configurations)
      @user_build_configurations = user_build_configurations
      # The configurations at the top level only need to exist, they don't hold
      # any build settings themselves, that's left to `add_pod_target`.
      user_build_configurations.each do |name, _|
        unless build_configurations.map(&:name).include?(name)
          build_configurations.new('name' => name)
        end
      end
    end

    # Shortcut access to the `Pods' PBXGroup.
    def pods
      groups.find { |g| g.name == 'Pods' } || groups.new({ 'name' => 'Pods' })
    end

    # Shortcut access to the `Local Pods' PBXGroup.
    def local_pods
      groups.find { |g| g.name == 'Local Pods' } || groups.new({ 'name' => 'Local Pods' })
    end

    # Adds a group as child to the `Pods' group namespacing subspecs.
    def add_spec_group(name, parent_group)
      groups = parent_group.groups
      group = nil
      name.split('/').each do |name|
        group = groups.find { |g| g.name == name } || groups.new('name' => name)
        groups = group.groups
      end
      group
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

      @user_build_configurations.each do |name, type|
        unless target.build_configurations.map(&:name).include?(name)
          config = target.build_configurations.new('name' => name)
          # Copy the settings from either the Debug or the Release configuration.
          config.build_settings = target.build_settings(type.to_s.capitalize).merge(settings)
        end
      end

      target
    end
  end
end
