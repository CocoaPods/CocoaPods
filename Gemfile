# Declares a dependency to the git repo of CocoaPods gem. This declaration is
# compatible with the local git repos feature of Bundler.
#
def cp_gem(name, repo_name, branch = 'master')
  url = "https://github.com/CocoaPods/#{repo_name}.git"
  gem name, :git => url, :branch => branch
end

source 'http://rubygems.org'

gemspec

group :development do
  cp_gem 'claide',               'CLAide'
  cp_gem 'cocoapods-core',       'Core'
  cp_gem 'cocoapods-downloader', 'cocoapods-downloader'
  cp_gem 'cocoapods-plugins',    'cocoapods-plugins'
  cp_gem 'cocoapods-trunk',      'cocoapods-trunk'
  cp_gem 'cocoapods-try',        'cocoapods-try'
  cp_gem 'xcodeproj',            'Xcodeproj'
  cp_gem 'molinillo',            'Molinillo'

  gem 'bacon'
  gem 'mocha'
  gem 'mocha-on-bacon'
  gem 'prettybacon'
  gem 'webmock'

  # Integration tests
  gem 'diffy'
  gem 'clintegracon'
  gem 'rubocop'

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
  gem 'ruby-prof'
end

