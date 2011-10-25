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

  module Xcode
    autoload :Config,               'cocoapods/xcode/config'
    autoload :CopyResourcesScript,  'cocoapods/xcode/copy_resources_script'
    autoload :Project,              'cocoapods/xcode/project'
    autoload :Workspace,            'cocoapods/xcode/workspace'
  end

  autoload :Pathname,               'pathname'
end

class Pathname
  def glob(pattern = '')
    Dir.glob((self + pattern).to_s).map { |f| Pathname.new(f) }
  end
end

