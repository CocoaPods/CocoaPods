module Pod
  VERSION = '0.3.9'

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
  autoload :Resolver,               'cocoapods/resolver'
  autoload :Source,                 'cocoapods/source'
  autoload :Spec,                   'cocoapods/specification'
  autoload :Specification,          'cocoapods/specification'
  autoload :Version,                'cocoapods/version'

  autoload :Pathname,               'pathname'
  autoload :FileList,               'cocoapods/file_list'

  module Generator
    autoload :BridgeSupport,        'cocoapods/generator/bridge_support'
    autoload :CopyResourcesScript,  'cocoapods/generator/copy_resources_script'
  end
end

module Xcodeproj
  autoload :Config,                 'xcodeproj/config'
  autoload :Project,                'cocoapods/xcodeproj_ext'
  autoload :Workspace,              'xcodeproj/workspace'
end

class Pathname
  def glob(pattern = '')
    Dir.glob((self + pattern).to_s).map { |f| Pathname.new(f) }
  end
end
