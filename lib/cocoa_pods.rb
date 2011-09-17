module Pod
  class Informative < StandardError
  end

  autoload :Command,       'cocoa_pods/command'
  autoload :Config,        'cocoa_pods/config'
  autoload :Dependency,    'cocoa_pods/dependency'
  autoload :Downloader,    'cocoa_pods/downloader'
  autoload :Executable,    'cocoa_pods/executable'
  autoload :Installer,     'cocoa_pods/installer'
  autoload :Resolver,      'cocoa_pods/resolver'
  autoload :Source,        'cocoa_pods/source'
  autoload :Spec,          'cocoa_pods/specification'
  autoload :Specification, 'cocoa_pods/specification'
  autoload :Version,       'cocoa_pods/version'

  module Xcode
    autoload :Config,      'cocoa_pods/xcode/config'
    autoload :Project,     'cocoa_pods/xcode/project'
  end

  autoload :Pathname,      'pathname'
end

class Pathname
  def glob(pattern = '')
    Dir.glob((self + pattern).to_s).map { |f| Pathname.new(f) }
  end
end

