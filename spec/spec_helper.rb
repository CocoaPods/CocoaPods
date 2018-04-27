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
require 'spec_helper/webmock'         # Cleans up mocks after each spec

#-----------------------------------------------------------------------------#

# README!
#
# Override {Specification#source} to return sources from fixtures and limit
# network connections.
#
module Pod
  class Specification
    def source
      fixture = SpecHelper.fixture("integration/#{name}")
      result = super
      result[:git] = fixture.to_s if fixture.exist?
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

  def self.reset_config_instance
    ::Pod::Config.instance = nil
    ::Pod::Config.instance.tap do |c|
      c.verbose           =  false
      c.silent            =  true
      c.repos_dir         =  fixture('spec-repos')
      c.installation_root =  SpecHelper.temporary_directory
      c.cache_root        =  SpecHelper.temporary_directory + 'Cache'
    end
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
  parent = Pod::Podfile.new
  Pod::Podfile::TargetDefinition.new(name, parent, 'abstract' => false, 'name' => name, 'platform' => platform_hash)
end

def fixture_pod_target(spec_or_name, host_requires_frameworks = false, user_build_configurations = {}, archs = [],
                       platform = Pod::Platform.new(:ios, '6.0'), target_definitions = [], scope_suffix = nil)
  spec = spec_or_name.is_a?(Pod::Specification) ? spec_or_name : fixture_spec(spec_or_name)
  fixture_pod_target_with_specs([spec], host_requires_frameworks, user_build_configurations, archs, platform,
                                target_definitions, scope_suffix)
end

def fixture_pod_target_with_specs(specs, host_requires_frameworks = false, user_build_configurations = {}, archs = [],
                                  platform = Pod::Platform.new(:ios, '6.0'), target_definitions = [],
                                  scope_suffix = nil)
  target_definitions << fixture_target_definition if target_definitions.empty?
  target_definitions.each { |td| specs.each { |spec| td.store_pod(spec.name) } }
  file_accessors = specs.map { |spec| fixture_file_accessor(spec, platform) }
  Pod::PodTarget.new(config.sandbox, host_requires_frameworks, user_build_configurations, archs, platform, specs,
                     target_definitions, file_accessors, scope_suffix)
end

def fixture_aggregate_target(pod_targets = [], host_requires_frameworks = false, user_build_configurations = Pod::Target::DEFAULT_BUILD_CONFIGURATIONS,
                             archs = [], platform = Pod::Platform.new(:ios, '6.0'), target_definition = nil)
  target_definition ||= pod_targets.flat_map(&:target_definitions).first || fixture_target_definition
  Pod::AggregateTarget.new(config.sandbox, host_requires_frameworks, user_build_configurations, archs, platform,
                           target_definition, config.sandbox.root.dirname, nil, nil, 'Release' => pod_targets)
end

#-----------------------------------------------------------------------------#

SpecHelper::Fixture.fixture('banana-lib') # ensure it exists
SpecHelper::Fixture.fixture('orange-framework')
