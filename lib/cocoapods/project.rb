require 'xcodeproj'

# Xcodeproj::Project::Object::PBXCopyFilesBuildPhase.instance_eval do
#   def self.new_pod_dir(project, pod_name, path)
#     new(project, nil, {
#       "dstPath" => "Pods/#{path}",
#       "name"    => "Copy #{pod_name} Public Headers",
#     })
#   end
# end

module Pod
  class Project < Xcodeproj::Project
    include Config::Mixin

    attr_reader :support_files_group

    def initialize(*)
      super
      podfile_path = config.project_podfile.relative_path_from(config.project_pods_root).to_s
      podfile_ref  = new_file(podfile_path)
      podfile_ref.xc_language_specification_identifier = 'xcode.lang.ruby'
      new_group('Pods')
      @support_files_group = new_group('Targets Support Files')
      @user_build_configurations = []
    end

    def user_build_configurations=(user_build_configurations)
      @user_build_configurations = user_build_configurations
      # The configurations at the top level only need to exist, they don't hold
      # any build settings themselves, that's left to `add_pod_target`.
      user_build_configurations.each do |name, _|
        unless build_configurations.map(&:name).include?(name)
          bc = new(XCBuildConfiguration)
          bc.name = name
          build_configurations << bc
        end
      end
    end

    # Shortcut access to the `Pods' PBXGroup.
    def pods
      @pods ||= self['Pods'] || new_group('Pods')
    end

    # Shortcut access to the `Local Pods' PBXGroup.
    def local_pods
      @local_pods ||= self['Local Pods'] || new_group('Local Pods')
    end

    # Adds a group as child to the `Pods' group namespacing subspecs.
    def add_spec_group(name, parent_group)
      current_group = parent_group
      group = nil
      name.split('/').each do |name|
        group = current_group[name] || current_group.new_group(name)
        current_group = group
      end
      group
    end

    def add_pod_target(name, platform)
      target = new_target(:static_library, name, platform.name)

      settings = {}
      if platform.requires_legacy_ios_archs?
        settings['ARCHS'] = "armv6 armv7"
      end

      if platform == :ios && platform.deployment_target
        # TODO: add for osx as well
        settings['IPHONEOS_DEPLOYMENT_TARGET'] = platform.deployment_target.to_s
      end

      target.build_settings('Debug').merge!(settings)
      target.build_settings('Release').merge!(settings)

      @user_build_configurations.each do |name, type|
        unless target.build_configurations.map(&:name).include?(name)
          bc = new(XCBuildConfiguration)
          bc.name = name
          target.build_configurations << bc
          # Copy the settings from either the Debug or the Release configuration.
          bc.build_settings = target.build_settings(type.to_s.capitalize).merge(settings)
        end
      end

      target
    end
  end
end
