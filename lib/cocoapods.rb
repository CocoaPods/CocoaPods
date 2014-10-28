require 'rubygems'
require 'xcodeproj'

# It is very likely that we'll need these and as some of those paths will atm
# result in a I18n deprecation warning, we load those here now so that we can
# get rid of that warning.
require 'active_support/core_ext/string/strip'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/array/conversions'
# TODO check what this actually does by the time we're going to add support for
# other locales.
require 'i18n'
if I18n.respond_to?(:enforce_available_locales=)
  I18n.enforce_available_locales = false
end

module Pod
  require 'pathname'

  require 'cocoapods/gem_version'
  require 'cocoapods-core'
  require 'cocoapods/config'
  require 'cocoapods/downloader'

  # Loaded immediately after dependencies to ensure proper override of their
  # UI methods.
  #
  require 'cocoapods/user_interface'

  # Indicates an user error. This is defined in cocoapods-core.
  #
  class Informative < PlainInformative
    def message
      "[!] #{super}".red
    end
  end

  autoload :AggregateTarget,           'cocoapods/target/aggregate_target'
  autoload :Command,                   'cocoapods/command'
  autoload :Executable,                'cocoapods/executable'
  autoload :ExternalSources,           'cocoapods/external_sources'
  autoload :Installer,                 'cocoapods/installer'
  autoload :HooksManager,              'cocoapods/hooks_manager'
  autoload :PodTarget,                 'cocoapods/target/pod_target'
  autoload :Project,                   'cocoapods/project'
  autoload :Resolver,                  'cocoapods/resolver'
  autoload :Sandbox,                   'cocoapods/sandbox'
  autoload :SourcesManager,            'cocoapods/sources_manager'
  autoload :Target,                    'cocoapods/target'
  autoload :Validator,                 'cocoapods/validator'

  module Generator
    autoload :Acknowledgements,        'cocoapods/generator/acknowledgements'
    autoload :Markdown,                'cocoapods/generator/acknowledgements/markdown'
    autoload :Plist,                   'cocoapods/generator/acknowledgements/plist'
    autoload :BridgeSupport,           'cocoapods/generator/bridge_support'
    autoload :CopyResourcesScript,     'cocoapods/generator/copy_resources_script'
    autoload :DummySource,             'cocoapods/generator/dummy_source'
    autoload :Header,                  'cocoapods/generator/header'
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
