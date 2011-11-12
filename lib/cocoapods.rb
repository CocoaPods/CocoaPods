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
  autoload :Resolver,               'cocoapods/resolver'
  autoload :Source,                 'cocoapods/source'
  autoload :Spec,                   'cocoapods/specification'
  autoload :Specification,          'cocoapods/specification'
  autoload :Version,                'cocoapods/version'

  autoload :Pathname,               'pathname'
end

module Xcode
  autoload :Config,                 'cocoapods/xcode_project'
  autoload :Project,                'cocoapods/xcode_project'
  autoload :Workspace,              'cocoapods/xcode_project'
end

class Pathname
  def glob(pattern = '')
    Dir.glob((self + pattern).to_s).map { |f| Pathname.new(f) }
  end
end
