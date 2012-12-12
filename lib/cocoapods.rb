require 'rubygems'

module Pod
  require 'cocoapods-core'
  require 'cocoapods/downloader'
  require 'cocoapods/file_list'
  require 'cocoapods/config'

  class PlainInformative < StandardError; end

  class Informative < PlainInformative
    def message
      # TODO: remove formatting from raise calls and remove conditional
      super !~ /\[!\]/ ? "[!] #{super}".red : super
    end
  end

  autoload :Command,                'cocoapods/command'
  autoload :Executable,             'cocoapods/executable'
  autoload :ExternalSources,        'cocoapods/external_sources'
  autoload :Installer,              'cocoapods/installer'
  autoload :SourcesManager,         'cocoapods/sources_manager'
  autoload :Library,                'cocoapods/library'
  autoload :LocalPod,               'cocoapods/local_pod'
  autoload :Project,                'cocoapods/project'
  autoload :Resolver,               'cocoapods/resolver'
  autoload :Sandbox,                'cocoapods/sandbox'
  autoload :UI,                     'cocoapods/user_interface'
  autoload :Validator,              'cocoapods/validator'

  autoload :Pathname,               'pathname'

  module Generator
    autoload :BridgeSupport,        'cocoapods/generator/bridge_support'
    autoload :CopyResourcesScript,  'cocoapods/generator/copy_resources_script'
    autoload :Documentation,        'cocoapods/generator/documentation'
    autoload :Acknowledgements,     'cocoapods/generator/acknowledgements'
    autoload :Plist,                'cocoapods/generator/acknowledgements/plist'
    autoload :Markdown,             'cocoapods/generator/acknowledgements/markdown'
    autoload :DummySource,          'cocoapods/generator/dummy_source'
    autoload :PrefixHeader,         'cocoapods/generator/prefix_header'
    autoload :XCConfig,             'cocoapods/generator/xcconfig'
  end

end

if ENV['COCOA_PODS_ENV'] == 'development'
  require 'awesome_print'
  require 'pry'
end
