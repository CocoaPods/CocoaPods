# Set up coverage analysis
#-----------------------------------------------------------------------------#


if ENV['CI'] || ENV['GENERATE_COVERAGE']
  require 'simplecov'
  require 'coveralls'

  if ENV['CI']
    SimpleCov.formatter = Coveralls::SimpleCov::Formatter
  elsif ENV['GENERATE_COVERAGE']
    SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
  end
  SimpleCov.start do
    add_filter "/spec_helper/"
  end
end

# TODO: Coverall loads colorize which interferes with colored making certain
# specs fail. This should be removed once Coverall is fixed.
#
# https://github.com/lemurheavy/coveralls-ruby/issues/14
#
require 'colored'

# Set up
#-----------------------------------------------------------------------------#

require 'rubygems'
require 'bundler/setup'
require 'bacon'
require 'mocha-on-bacon'
require 'pathname'
require "active_support/core_ext/string/strip"

ROOT = Pathname.new(File.expand_path('../../', __FILE__))
$:.unshift((ROOT + 'lib').to_s)
$:.unshift((ROOT + 'spec').to_s)

require 'cocoapods'
require 'claide'
require 'awesome_print'

require 'spec_helper/bacon'           # Prettifies the bacon output and adds support for `xit`.
require 'spec_helper/command'         # Allows to run Pod commands and returns their output.
require 'spec_helper/fixture'         # Provides access to the fixtures and unpacks them if needed.
require 'spec_helper/temporary_repos' # Allows to create and modify temporary spec repositories.
require 'spec_helper/user_interface'  # Redirects UI to UI.output & UI.warnings.
require 'spec_helper/pre_flight'      # Cleans the temporary directory, the config & the UI.output before every test.
require 'spec_helper/github'          # Stubs Github API to return always the values (watchers).

#-----------------------------------------------------------------------------#

# README!
#
# Override {Specification#source} to return sources from fixtures and limit
# network connections.
#
module Pod
  class Specification
    alias :original_source :source
    def source
      fixture = SpecHelper.fixture("integration/#{name}")
      result = super
      if fixture.exist?
        # puts "Using fixture [#{name}]"
        result[:git] = fixture.to_s
      else
        # puts "MISSING fixture [#{name}]"
      end
      result
    end
  end
end

#-----------------------------------------------------------------------------#

ENV['SKIP_SETUP'] = 'true'
if ENV['SKIP_XCODEBUILD'].nil? && `which xcodebuild`.strip.empty?
  ENV['SKIP_XCODEBUILD'] = 'true'
end

Bacon.summary_at_exit

module Bacon
  class Context
    include Pod::Config::Mixin
    include SpecHelper::Fixture
    include SpecHelper::Command

    def skip_xcodebuild?
      ENV['SKIP_XCODEBUILD']
    end

    def temporary_directory
      SpecHelper.temporary_directory
    end
  end
end

module SpecHelper
  def self.temporary_directory
    ROOT + 'tmp'
  end
end

def temporary_sandbox
  Pod::Sandbox.new(temporary_directory + "Pods")
end

def fixture_spec(name)
  file = SpecHelper::Fixture.fixture(name)
  Pod::Specification.from_file(file)
end

def fixture_file_accessor(name, platform = :ios)
  file = SpecHelper::Fixture.fixture(name)
  spec = Pod::Specification.from_file(file)
  path_list = Pod::Sandbox::PathList.new(file.dirname)
  Pod::Sandbox::FileAccessor.new(path_list, spec.consumer(platform))
end

#-----------------------------------------------------------------------------#

SpecHelper::Fixture.fixture('banana-lib') # ensure it exists

