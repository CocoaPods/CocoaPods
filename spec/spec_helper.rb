# Set up coverage analysis
#-----------------------------------------------------------------------------#

# if Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new("1.9")
#   if ENV['CI'] || ENV['GENERATE_COVERAGE']
#     require 'simplecov'
#     require 'coveralls'
#
#     if ENV['CI']
#       SimpleCov.formatter = Coveralls::SimpleCov::Formatter
#     elsif ENV['GENERATE_COVERAGE']
#       SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
#     end
#     SimpleCov.start do
#       add_filter "/spec_helper/"
#     end
#   end
# end

# Set up
#-----------------------------------------------------------------------------#

require 'rubygems'
require 'bundler/setup'
require 'bacon'
require 'mocha-on-bacon'
require 'pretty_bacon'
require 'pathname'

require 'active_support/core_ext/string/strip'
require 'active_support/core_ext/object/deep_dup'

ROOT = Pathname.new(File.expand_path('../../', __FILE__))
$:.unshift((ROOT + 'lib').to_s)
$:.unshift((ROOT + 'spec').to_s)

require 'cocoapods'
require 'claide'
# require 'awesome_print'

require 'spec_helper/command'         # Allows to run Pod commands and returns their output.
require 'spec_helper/fixture'         # Provides access to the fixtures and unpacks them if needed.
require 'spec_helper/temporary_repos' # Allows to create and modify temporary spec repositories.
require 'spec_helper/temporary_cache' # Allows to create temporary cache directory.
require 'spec_helper/user_interface'  # Redirects UI to UI.output & UI.warnings.
require 'spec_helper/pre_flight'      # Cleans the temporary directory, the config & the UI.output before every test.

#-----------------------------------------------------------------------------#

# README!
#
# Override {Specification#source} to return sources from fixtures and limit
# network connections.
#
module Pod
  class Specification
    alias_method :original_source, :source
    def source
      fixture = SpecHelper.fixture("integration/#{name}")
      result = super
      if fixture.exist?
        # puts "Using fixture [#{name}]"
        result[:git] = fixture.to_s
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

Mocha::Configuration.prevent(:stubbing_non_existent_method)

module SpecHelper
  def self.temporary_directory
    ROOT + 'tmp'
  end
end

def temporary_sandbox
  Pod::Sandbox.new(temporary_directory + 'Pods')
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

def fixture_target_definition(podfile = nil, &block)
  podfile ||= Pod::Podfile.new(&block)
  Pod::Podfile::TargetDefinition.new('Pods', podfile)
end

def fixture_pod_target(spec_or_name, platform = :ios, target_definition = nil)
  spec = spec_or_name.is_a?(Pod::Specification) ? spec_or_name : fixture_spec(spec_or_name)
  target_definition ||= fixture_target_definition
  target_definition.store_pod(spec.name)
  Pod::PodTarget.new([spec], [target_definition], config.sandbox).tap do |pod_target|
    pod_target.stubs(:platform).returns(platform)
    pod_target.file_accessors << fixture_file_accessor(spec.defined_in_file, platform)
    consumer = spec.consumer(platform)
    pod_target.spec_consumers << consumer
  end
end

def fixture_aggregate_target(pod_targets = [], platform = :ios, target_definition = nil)
  target_definition ||= pod_targets.map(&:target_definition).first || fixture_target_definition
  target = Pod::AggregateTarget.new(target_definition, config.sandbox)
  target.client_root = config.sandbox.root.dirname
  version ||= (platform == :ios ? '4.3' : '10.6')
  target.stubs(:platform).returns(Pod::Platform.new(platform, version))
  target.pod_targets = pod_targets
  target
end

#-----------------------------------------------------------------------------#

SpecHelper::Fixture.fixture('banana-lib') # ensure it exists
SpecHelper::Fixture.fixture('orange-framework')
