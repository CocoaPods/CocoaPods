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

    module_function :set_up_test_cache, :tmp_cache_path

  end
end
