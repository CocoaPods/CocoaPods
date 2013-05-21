source "http://rubygems.org"

unless defined?(Pod::VERSION)
  ::BUNDLER_GEMSPEC = true unless defined?(::BUNDLER_GEMSPEC)
end
gemspec

group :development do
  # To develop the deps in tandem use the `LOCAL GIT REPOS` feature of Bundler.
  gem 'cocoapods-core',       :git => "https://github.com/CocoaPods/Core.git", :branch => 'master'
  gem 'xcodeproj',            :git => "https://github.com/CocoaPods/Xcodeproj.git", :branch => 'xcconfig-prefix'
  gem 'cocoapods-downloader', :git => "https://github.com/CocoaPods/cocoapods-downloader.git", :branch => 'master'
  gem 'claide',               :git => 'https://github.com/CocoaPods/CLAide.git', :branch => 'master'

  gem "mocha"
  gem "bacon"
  gem "mocha-on-bacon"
  gem 'prettybacon', :git => 'https://github.com/irrationalfab/PrettyBacon.git', :branch => 'master'
  gem "rake"
  gem 'coveralls', :require => false, :git => 'https://github.com/lemurheavy/coveralls-ruby.git'
end

group :debugging do
  gem "rb-fsevent"
  gem "kicker", :git => "https://github.com/alloy/kicker.git", :branch => "3.0.0"
  gem "awesome_print"
  gem "pry"
  gem "diffy"
  gem "ruby-prof"
end

group :documentation do
  gem 'yard'
  gem 'redcarpet'
  gem 'github-markup'
  gem 'pygments.rb'
end

