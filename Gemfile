SKIP_UNRELEASED_VERSIONS = false

# Declares a dependency to the git repo of CocoaPods gem. This declaration is
# compatible with the local git repos feature of Bundler.
#
def cp_gem(name, repo_name, branch = 'master', path: false)
  return gem name if SKIP_UNRELEASED_VERSIONS
  opts = if path
           { :path => "../#{repo_name}" }
         else
           url = "https://github.com/CocoaPods/#{repo_name}.git"
           { :git => url, :branch => branch }
         end
  gem name, opts
end

source 'https://rubygems.org'

gemspec

# This is the version that ships with OS X 10.10, so be sure we test against it.
# At the same time, the 1.7.7 version won't install cleanly on Ruby > 2.2,
# so we use a fork that makes a trivial change to a macro invocation.
gem 'json', :git => 'https://github.com/segiddins/json.git', :branch => 'seg-1.7.7-ruby-2.2'

group :development do
  cp_gem 'claide',                'CLAide'
  cp_gem 'cocoapods-core',        'Core', '1-10-stable'
  cp_gem 'cocoapods-deintegrate', 'cocoapods-deintegrate'
  cp_gem 'cocoapods-downloader',  'cocoapods-downloader'
  cp_gem 'cocoapods-plugins',     'cocoapods-plugins'
  cp_gem 'cocoapods-search',      'cocoapods-search'
  cp_gem 'cocoapods-trunk',       'cocoapods-trunk'
  cp_gem 'cocoapods-try',         'cocoapods-try'
  gem 'molinillo', :git => 'https://github.com/CocoaPods/Molinillo.git', :tag => '0.6.6'
  cp_gem 'nanaimo',               'Nanaimo'

  cp_gem 'xcodeproj',             'Xcodeproj'

  gem 'cocoapods-dependencies', '~> 1.0.beta.1'

  gem 'activesupport', '> 5', '< 6' # Pinned < 6 because 6 requires Ruby 2.5.0
  gem 'bacon', :git => 'https://github.com/leahneukirchen/bacon.git'
  gem 'mocha', '< 1.5'
  gem 'mocha-on-bacon'
  gem 'netrc'
  gem 'prettybacon'
  gem 'typhoeus'
  gem 'webmock'

  gem 'bigdecimal', '~> 1.3.0'
  gem 'public_suffix'
  gem 'ruby-graphviz', '< 1.2.5'

  # Integration tests
  gem 'diffy'
  gem 'clintegracon'

  # Code Quality
  gem 'inch_by_inch'
  gem 'rubocop', '0.50.0'
  gem 'simplecov', '< 0.18'

  gem 'danger', '~> 5.3'
end

group :debugging do
  gem 'cocoapods_debug'

  gem 'rb-fsevent'
  gem 'kicker'
  gem 'awesome_print'
  gem 'ruby-prof', :platforms => [:ruby]
end
