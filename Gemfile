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

group :development do
  cp_gem 'claide',                'CLAide'
  cp_gem 'cocoapods-core',        'Core'
  cp_gem 'cocoapods-deintegrate', 'cocoapods-deintegrate'
  cp_gem 'cocoapods-downloader',  'cocoapods-downloader'
  cp_gem 'cocoapods-plugins',     'cocoapods-plugins'
  cp_gem 'cocoapods-search',      'cocoapods-search'
  cp_gem 'cocoapods-trunk',       'cocoapods-trunk'
  cp_gem 'cocoapods-try',         'cocoapods-try'
  cp_gem 'molinillo',             'Molinillo'
  cp_gem 'nanaimo',               'Nanaimo'
  cp_gem 'xcodeproj',             'Xcodeproj'

  gem 'cocoapods-dependencies', '~> 1.0.beta.1'

  # Pin activesupport to < 7 because we still test with Ruby 2.6 in CI.
  gem 'activesupport', '> 5', '< 7'
  gem 'bacon', :git => 'https://github.com/leahneukirchen/bacon.git'
  gem 'mocha', '< 1.5'
  gem 'mocha-on-bacon'
  gem 'netrc'
  gem 'prettybacon'
  gem 'typhoeus'
  gem 'webmock'

  gem 'bigdecimal', '~> 3.0'
  gem 'public_suffix'
  gem 'ruby-graphviz', '< 1.2.5'

  # Integration tests
  gem 'diffy'
  gem 'clintegracon', :git => 'https://github.com/mrackwitz/CLIntegracon.git'

  # Code Quality

  # Revert to released gem once https://github.com/segiddins/inch_by_inch/pull/5 lands and a new version is published
  gem 'inch_by_inch', :git => 'https://github.com/CocoaPods/inch_by_inch.git', :branch => 'loosen-dependency'
  gem 'rubocop', '0.50.0'
  gem 'simplecov', '< 0.18'

  gem 'octokit', '~> 4.18.0'

  gem 'danger', '~> 8.0'
end

group :debugging do
  gem 'cocoapods_debug'

  gem 'rb-fsevent'
  gem 'kicker'
  gem 'awesome_print'
  gem 'ruby-prof', :platforms => [:ruby]
end
