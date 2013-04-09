require 'rubygems'

autoload :Xcodeproj, 'xcodeproj'

module Pod
  require 'pathname'

  require 'cocoapods/gem_version'
  require 'cocoapods-core'
  require 'cocoapods/file_list'
  require 'cocoapods/config'

  autoload :Downloader, 'cocoapods/downloader'

  # Indicates an user error. This is defined in cocoapods-core.
  #
  class Informative < PlainInformative
    def message
      "[!] #{super}".red
    end
  end

  # @return [Pathname] The directory where CocoaPods caches the downloads.
  #
  # @todo   The {Installer::PodSourceInstaller} and the #{ExternalSources}
  #         classes build and configure the downloader from scratch.
  #
  CACHE_ROOT = Pathname.new(File.join(ENV['HOME'], 'Library/Caches/CocoaPods'))
  CACHE_ROOT.mkpath unless CACHE_ROOT.exist?

  # @return [Fixnum] The maximum size for the cache expressed in Mb.
  #
  # @todo   The {Installer::PodSourceInstaller} and the #{ExternalSources}
  #         classes build and configure the downloader from scratch.
  #
  MAX_CACHE_SIZE = 500

  # @return [Pathname] The file to use a cache of the statistics provider.
  #
  STATISTICS_CACHE_FILE = CACHE_ROOT + 'statistics.yml'

  autoload :Command,                   'cocoapods/command'
  autoload :Executable,                'cocoapods/executable'
  autoload :ExternalSources,           'cocoapods/external_sources'
  autoload :Installer,                 'cocoapods/installer'
  autoload :SourcesManager,            'cocoapods/sources_manager'
  autoload :Library,                   'cocoapods/library'
  autoload :Project,                   'cocoapods/project'
  autoload :Resolver,                  'cocoapods/resolver'
  autoload :Sandbox,                   'cocoapods/sandbox'
  autoload :UI,                        'cocoapods/user_interface'
  autoload :Validator,                 'cocoapods/validator'

  module Generator
    autoload :Acknowledgements,        'cocoapods/generator/acknowledgements'
    autoload :BridgeSupport,           'cocoapods/generator/bridge_support'
    autoload :CopyResourcesScript,     'cocoapods/generator/copy_resources_script'
    autoload :Documentation,           'cocoapods/generator/documentation'
    autoload :DummySource,             'cocoapods/generator/dummy_source'
    autoload :Markdown,                'cocoapods/generator/acknowledgements/markdown'
    autoload :Plist,                   'cocoapods/generator/acknowledgements/plist'
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
