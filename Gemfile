source "http://rubygems.org"

unless defined?(Pod::VERSION)
  ::BUNDLER_GEMSPEC = true unless defined?(::BUNDLER_GEMSPEC)
end
gemspec

group :development do
  # To develop the deps in tandem use the `LOCAL GIT REPOS` feature of Bundler.
  # For more info see http://bundler.io/git.html#local
  gem 'cocoapods-core',       :git => "https://github.com/CocoaPods/Core.git", :branch => 'master'
  gem 'xcodeproj',            :git => "https://github.com/CocoaPods/Xcodeproj.git", :branch => 'master'
  gem 'cocoapods-downloader', :git => "https://github.com/CocoaPods/cocoapods-downloader.git", :branch => 'master'
  gem 'claide',               :git => 'https://github.com/CocoaPods/CLAide.git', :branch => 'master'

  gem "mocha"
  gem "bacon"
  gem "mocha-on-bacon"
  gem 'prettybacon', :git => 'https://github.com/irrationalfab/PrettyBacon.git', :branch => 'master'
  gem "rake"

  # For the integration tests
  gem "diffy"

  gem 'mime-types', '< 2' # v2 is 1.9.x only
  gem 'coveralls', :require => false
  # Explicitly add this, otherwise it might sometimes be missing:
  # https://github.com/lemurheavy/coveralls-ruby/blob/master/coveralls-ruby.gemspec#L23.
  gem 'simplecov'
end

group :debugging do
  gem "rb-fsevent"
  gem "kicker", :git => "https://github.com/alloy/kicker.git", :branch => "master"
  gem "awesome_print"
  gem "pry"
  gem "ruby-prof"
end

group :documentation do
  gem 'yard'
  gem 'redcarpet', '< 3.0.0' # Not compatible with MRI 1.8.7
  gem 'github-markup'
  gem 'pygments.rb'
end

