module Pod
  VERSION = '0.0.1'

  class Informative < StandardError
  end

  autoload :Command,       'cocoapods/command'
  autoload :Config,        'cocoapods/config'
  autoload :Dependency,    'cocoapods/dependency'
  autoload :Downloader,    'cocoapods/downloader'
  autoload :Executable,    'cocoapods/executable'
  autoload :Installer,     'cocoapods/installer'
  autoload :Resolver,      'cocoapods/resolver'
  autoload :Source,        'cocoapods/source'
  autoload :Spec,          'cocoapods/specification'
  autoload :Specification, 'cocoapods/specification'
  autoload :Version,       'cocoapods/version'

  module Xcode
    autoload :Config,      'cocoapods/xcode/config'
    autoload :Project,     'cocoapods/xcode/project'
  end

  autoload :Pathname,      'pathname'
end

class Pathname
  def glob(pattern = '')
    Dir.glob((self + pattern).to_s).map { |f| Pathname.new(f) }
  end
end

