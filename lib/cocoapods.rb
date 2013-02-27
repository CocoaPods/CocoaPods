require 'rubygems'

module Pod
  require 'cocoapods/gem_version'

  # Indicates a runtime error **not** caused by a bug.
  #
  class PlainInformative < StandardError; end

  # Indicates a runtime error **not** caused by a bug which should be
  # highlighted to the user.
  #
  class Informative < PlainInformative
    def message
      "[!] #{super}".red
    end
  end

  # @return [String] The directory where CocoaPods caches the downloads.
  #
  # @todo   The {Installer::PodSourceInstaller} and the #{ExternalSources}
  #         classes build and configure the downloader from scratch.
  #
  CACHE_ROOT = "~/Library/Caches/CocoaPods"

  # @return [Fixnum] The maximum size for the cache expressed in Mb.
  #
  # @todo   The {Installer::PodSourceInstaller} and the #{ExternalSources}
  #         classes build and configure the downloader from scratch.
  #
  MAX_CACHE_SIZE = 500

  require 'cocoapods-core'
  require 'xcodeproj'
  require 'cocoapods/downloader'
  require 'cocoapods/file_list'
  require 'cocoapods/config'

  autoload :Command,                'cocoapods/command'
  autoload :Executable,             'cocoapods/executable'
  autoload :ExternalSources,        'cocoapods/external_sources'
  autoload :Installer,              'cocoapods/installer'
  autoload :SourcesManager,         'cocoapods/sources_manager'
  autoload :Library,                'cocoapods/library'
  autoload :Project,                'cocoapods/project'
  autoload :Resolver,               'cocoapods/resolver'
  autoload :Sandbox,                'cocoapods/sandbox'
  autoload :UI,                     'cocoapods/user_interface'
  autoload :Validator,              'cocoapods/validator'

  autoload :Pathname,               'pathname'

  module Generator
    autoload :Acknowledgements,     'cocoapods/generator/acknowledgements'
    autoload :BridgeSupport,        'cocoapods/generator/bridge_support'
    autoload :CopyResourcesScript,  'cocoapods/generator/copy_resources_script'
    autoload :Documentation,        'cocoapods/generator/documentation'
    autoload :DummySource,          'cocoapods/generator/dummy_source'
    autoload :Markdown,             'cocoapods/generator/acknowledgements/markdown'
    autoload :Plist,                'cocoapods/generator/acknowledgements/plist'
    autoload :PrefixHeader,         'cocoapods/generator/prefix_header'
    autoload :TargetHeader,         'cocoapods/generator/target_header'
    autoload :XCConfig,             'cocoapods/generator/xcconfig'
  end

  module Hooks
    autoload :InstallerRepresentation, 'cocoapods/hooks/installer_representation'
    autoload :LibraryRepresentation,   'cocoapods/hooks/library_representation'
    autoload :PodRepresentation,       'cocoapods/hooks/pod_representation'
  end

end

if ENV['COCOA_PODS_ENV'] == 'development'
  require 'awesome_print'
  require 'pry'
end
