require 'rubygems'
require 'xcodeproj'

module Pod
  require 'pathname'

  require 'cocoapods/gem_version'
  require 'cocoapods-core'
  require 'cocoapods/config'
  require 'cocoapods/downloader'

  # Indicates an user error. This is defined in cocoapods-core.
  #
  class Informative < PlainInformative
    def message
      puts "CALL"
      "[!] #{super}".red
    end
  end

  autoload :Command,                   'cocoapods/command'
  autoload :Executable,                'cocoapods/executable'
  autoload :ExternalSources,           'cocoapods/external_sources'
  autoload :Installer,                 'cocoapods/installer'
  autoload :SourcesManager,            'cocoapods/sources_manager'
  autoload :Target,                    'cocoapods/target'
  autoload :AggregateTarget,           'cocoapods/target'
  autoload :PodTarget,                 'cocoapods/target'
  autoload :Project,                   'cocoapods/project'
  autoload :Resolver,                  'cocoapods/resolver'
  autoload :Sandbox,                   'cocoapods/sandbox'
  autoload :UI,                        'cocoapods/user_interface'
  autoload :Validator,                 'cocoapods/validator'

  module Generator
    autoload :Acknowledgements,        'cocoapods/generator/acknowledgements'
    autoload :Markdown,                'cocoapods/generator/acknowledgements/markdown'
    autoload :Plist,                   'cocoapods/generator/acknowledgements/plist'
    autoload :BridgeSupport,           'cocoapods/generator/bridge_support'
    autoload :CopyResourcesScript,     'cocoapods/generator/copy_resources_script'
    autoload :DummySource,             'cocoapods/generator/dummy_source'
    autoload :PrefixHeader,            'cocoapods/generator/prefix_header'
    autoload :TargetEnvironmentHeader, 'cocoapods/generator/target_environment_header'
    autoload :XCConfig,                'cocoapods/generator/xcconfig'
  end

  module Hooks
    autoload :InstallerRepresentation, 'cocoapods/hooks/installer_representation'
    autoload :LibraryRepresentation,   'cocoapods/hooks/library_representation'
    autoload :PodRepresentation,       'cocoapods/hooks/pod_representation'
  end

end

if ENV['COCOA_PODS_ENV'] == 'development'
  # require 'awesome_print'
  # require 'pry'
end
