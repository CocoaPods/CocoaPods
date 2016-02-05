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
if ENV['SKIP_XCODEBUILD'].nil? && Pod::Executable.which('xcodebuild').nil?
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

def fixture_file_accessor(spec_or_name, platform = Pod::Platform.ios)
  spec = spec_or_name.is_a?(Pod::Specification) ? spec_or_name : fixture_spec(spec_or_name)
  path_list = Pod::Sandbox::PathList.new(spec.defined_in_file.dirname)
  Pod::Sandbox::FileAccessor.new(path_list, spec.consumer(platform))
end

def fixture_target_definition(name = 'Pods', platform = Pod::Platform.ios)
  platform_hash = { platform.symbolic_name => platform.deployment_target }
  Pod::Podfile::TargetDefinition.new(name, Pod::Podfile.new, 'name' => name, 'platform' => platform_hash)
end

def fixture_pod_target(spec_or_name, target_definitions = [])
  spec = spec_or_name.is_a?(Pod::Specification) ? spec_or_name : fixture_spec(spec_or_name)
  target_definitions << fixture_target_definition if target_definitions.empty?
  target_definitions.each { |td| td.store_pod(spec.name) }
  Pod::PodTarget.new([spec], target_definitions, config.sandbox).tap do |pod_target|
    pod_target.file_accessors << fixture_file_accessor(spec, pod_target.platform)
    consumer = spec.consumer(pod_target.platform)
    pod_target.spec_consumers << consumer
  end
end

def fixture_aggregate_target(pod_targets = [], target_definition = nil)
  target_definition ||= pod_targets.flat_map(&:target_definitions).first || fixture_target_definition
  target = Pod::AggregateTarget.new(target_definition, config.sandbox)
  target.client_root = config.sandbox.root.dirname
  target.pod_targets = pod_targets
  target
end

#-----------------------------------------------------------------------------#

SpecHelper::Fixture.fixture('banana-lib') # ensure it exists
SpecHelper::Fixture.fixture('orange-framework')
