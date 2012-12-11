require 'rubygems'

# Better to fail early and clear then during installation of pods.
#
# RubyGems 1.3.6 (which ships with OS X >= 10.7) up to 1.4.0 have a couple of
# bugs related to comparing prerelease versions.
#
# E.g. https://github.com/CocoaPods/CocoaPods/issues/398
unless Gem::Version::Requirement.new('>= 1.4.0').satisfied_by?(Gem::Version.new(Gem::VERSION))
  STDERR.puts "\e[1;31m" + "Your RubyGems version (1.8.24) is too old, please update with: `gem update --system`" + "\e[0m"
  exit 1
end

module Pod
  class PlainInformative < StandardError
  end

  class Informative < PlainInformative
    def message
      # TODO: remove formatting from raise calls and remove conditional
      super !~ /\[!\]/ ? "[!] #{super}".red : super
    end
  end

  autoload :Command,                'cocoapods/command'
  autoload :Downloader,             'cocoapods/downloader'
  autoload :Executable,             'cocoapods/executable'
  autoload :ExternalSources,        'cocoapods/external_sources'
  autoload :Installer,              'cocoapods/installer'
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

  require 'cocoapods/file_list'
  require 'cocoapods-core'
  require 'cocoapods/config'
  require 'cocoapods/source'
end

if ENV['COCOA_PODS_ENV'] == 'development'
  require 'awesome_print'
  require 'pry'
end
