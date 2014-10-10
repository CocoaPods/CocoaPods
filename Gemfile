source 'http://rubygems.org'

gemspec

group :development do
  # Declare dependencies to the git repos of CocoaPods gems. These declarations
  # are compatible with the local git repos feature of Bundler.
  gem 'claide',               :git => 'https://github.com/CocoaPods/CLAide.git',               :branch => 'master'
  gem 'cocoapods-core',       :git => 'https://github.com/CocoaPods/Core.git',                 :branch => 'master'
  gem 'cocoapods-downloader', :git => 'https://github.com/CocoaPods/cocoapods-downloader.git', :branch => 'master'
  gem 'cocoapods-plugins',    :git => 'https://github.com/CocoaPods/cocoapods-plugins.git',    :branch => 'master'
  gem 'cocoapods-trunk',      :git => 'https://github.com/CocoaPods/cocoapods-trunk.git',      :branch => 'master'
  gem 'cocoapods-try',        :git => 'https://github.com/CocoaPods/cocoapods-try.git',        :branch => 'master'
  gem 'xcodeproj',            :git => 'https://github.com/CocoaPods/Xcodeproj.git',            :branch => 'master'

  gem 'bacon'
  gem 'mocha'
  gem 'mocha-on-bacon'
  gem 'prettybacon'
  gem 'webmock'

  # Integration tests
  gem 'diffy'
  gem 'clintegracon'

  if RUBY_VERSION >= '1.9.3'
    gem 'rubocop'
  end

  if RUBY_PLATFORM.include?('darwin')
    # Make Xcodeproj faster
    gem 'libxml-ruby'
  end
end

group :debugging do
  gem 'rb-fsevent'
  gem 'kicker'
  gem 'awesome_print'
  gem 'pry'
end

group :ruby_1_8_7 do
  # Lock the current lowest requirement for ActiveSupport 3 to ensure we don't
  # re-introduce https://github.com/CocoaPods/CocoaPods/issues/1950
  gem 'i18n', '0.6.4'
  gem 'mime-types', '< 2.0'
  gem 'activesupport', '< 4'
end
