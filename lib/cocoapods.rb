module Pod
  VERSION = '0.6.0.rc4'

  class PlainInformative < StandardError
  end

  class Informative < PlainInformative
    def message
      #TODO: remove formatting from raise calls and remove conditional
      super !~ /\[!\]/ ? "[!] #{super}\n".red : super
    end
  end

  autoload :Command,                'cocoapods/command'
  autoload :Config,                 'cocoapods/config'
  autoload :Dependency,             'cocoapods/dependency'
  autoload :Downloader,             'cocoapods/downloader'
  autoload :Executable,             'cocoapods/executable'
  autoload :Installer,              'cocoapods/installer'
  autoload :LocalPod,               'cocoapods/local_pod'
  autoload :Platform,               'cocoapods/platform'
  autoload :Podfile,                'cocoapods/podfile'
  autoload :Project,                'cocoapods/project'
  autoload :Resolver,               'cocoapods/resolver'
  autoload :Sandbox,                'cocoapods/sandbox'
  autoload :Source,                 'cocoapods/source'
  autoload :Spec,                   'cocoapods/specification'
  autoload :Specification,          'cocoapods/specification'
  autoload :Version,                'cocoapods/version'

  autoload :Pathname,               'pathname'
  autoload :FileList,               'cocoapods/file_list'

  module Generator
    autoload :BridgeSupport,        'cocoapods/generator/bridge_support'
    autoload :CopyResourcesScript,  'cocoapods/generator/copy_resources_script'
    autoload :Documentation,        'cocoapods/generator/documentation'
    autoload :Acknowledgements,     'cocoapods/generator/acknowledgements'
    autoload :Plist,                'cocoapods/generator/acknowledgements/plist'
    autoload :Markdown,             'cocoapods/generator/acknowledgements/markdown'
    autoload :DummySource,          'cocoapods/generator/dummy_source'
  end
end

class Pathname
  def glob(pattern = '')
    Dir.glob((self + pattern).to_s).map { |f| Pathname.new(f) }
  end
end

if ENV['COCOA_PODS_ENV'] == 'development'
  require 'pry'
  require 'awesome_print'
end
