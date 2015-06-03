require File.expand_path('../fixture', __FILE__)

module SpecHelper
  module TemporaryCache
    # Sets up a lighweight cache in `tmp/cocoapods/cache` with the
    # contents of `spec/fixtures/cache/CocoaPods`.
    #
    def set_up_test_cache
      require 'fileutils'
      fixture_path = SpecHelper::Fixture.fixture('cache')
      destination = SpecHelper.temporary_directory + 'cocoapods'
      FileUtils.rm_rf(destination)
      destination.mkpath
      FileUtils.cp_r(fixture_path, destination)
      # Add version file so that the cache isn't imploded on version mismatch
      # (We don't include it in the tar.gz as we don't want to regenerate it each time)
      version_file = tmp_cache_path + 'Pods/VERSION'
      version_file.open('w') { |f| f << Pod::VERSION }
    end

    def tmp_cache_path
      SpecHelper.temporary_directory + 'cocoapods/cache/CocoaPods'
    end

    def test_cache_yaml(short = false)
      cache_root = "#{tmp_cache_path}/Pods"
      root_path = short ? '' : "#{cache_root}/"
      yaml = {
        'AFNetworking' => [
          { 'Version' => '2.5.4',
            'Type' => 'External',
            'Spec' => "#{root_path}Specs/External/AFNetworking/d9ac25e7b83cea885663771c90998c47.podspec.json",
            'Pod' => "#{root_path}External/AFNetworking/e84d20f40f2049470632ce56ff0ce26f-05edc",
          },
          { 'Version' => '2.5.4',
            'Type' => 'Release',
            'Spec' => "#{root_path}Specs/Release/AFNetworking/2.5.podspec.json",
            'Pod' => "#{root_path}Release/AFNetworking/2.5.4-05edc",
          },
        ],
        'CocoaLumberjack' => [
          { 'Version' => '2.0.0',
            'Type' => 'Release',
            'Spec' => "#{root_path}Specs/Release/CocoaLumberjack/2.0.podspec.json",
            'Pod' => "#{root_path}Release/CocoaLumberjack/2.0.0-a6f77",
          },
        ],
      }
      yaml['$CACHE_ROOT'] = cache_root if short
      yaml
    end

    module_function :set_up_test_cache, :tmp_cache_path, :test_cache_yaml
  end
end
