require 'rubygems'
require 'xcodeproj'

module Pod
  VERSION = '0.2.0'

  class Informative < StandardError
  end

  autoload :BridgeSupportGenerator, 'cocoapods/bridge_support_generator'
  autoload :Command,                'cocoapods/command'
  autoload :Config,                 'cocoapods/config'
  autoload :Dependency,             'cocoapods/dependency'
  autoload :Downloader,             'cocoapods/downloader'
  autoload :Executable,             'cocoapods/executable'
  autoload :Installer,              'cocoapods/installer'
  autoload :Podfile,                'cocoapods/podfile'
  autoload :ProjectTemplate,        'cocoapods/project_template'
  autoload :Resolver,               'cocoapods/resolver'
  autoload :Source,                 'cocoapods/source'
  autoload :Spec,                   'cocoapods/specification'
  autoload :Specification,          'cocoapods/specification'
  autoload :Version,                'cocoapods/version'

  autoload :Pathname,               'pathname'
end

class Pathname
  def glob(pattern = '')
    Dir.glob((self + pattern).to_s).map { |f| Pathname.new(f) }
  end
end

# Sorry to dump these here...

class Xcode::Project
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
