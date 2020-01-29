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
require 'spec_helper/mock_source'     # Allows building a mock source from Spec objects.

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

def fixture_target_definition(name = 'Pods', platform = Pod::Platform.ios, contents: {})
  parent = Pod::Podfile.new
  contents = {
    'abstract' => false,
    'name' => name,
    'platform' => { platform.symbolic_name => platform.deployment_target },
  }.merge(contents)
  Pod::Podfile::TargetDefinition.new(name, parent, contents)
end

def fixture_pod_target(spec_or_name, build_type = Pod::BuildType.static_library,
                       user_build_configurations = Pod::Target::DEFAULT_BUILD_CONFIGURATIONS, archs = [],
                       platform = Pod::Platform.new(:ios, '6.0'), target_definitions = [], scope_suffix = nil,
                       swift_version = nil)
  spec = spec_or_name.is_a?(Pod::Specification) ? spec_or_name : fixture_spec(spec_or_name)
  fixture_pod_target_with_specs([spec], build_type, user_build_configurations, archs, platform, target_definitions,
                                scope_suffix, swift_version)
end

def fixture_pod_target_with_specs(specs, build_type = Pod::BuildType.static_library,
                                  user_build_configurations = Pod::Target::DEFAULT_BUILD_CONFIGURATIONS, archs = [],
                                  platform = Pod::Platform.new(:ios, '6.0'), target_definitions = [],
                                  scope_suffix = nil, swift_version = nil)
  target_definitions << fixture_target_definition if target_definitions.empty?
  target_definitions.each { |td| specs.each { |spec| td.store_pod(spec.name) } }
  file_accessors = specs.map { |spec| fixture_file_accessor(spec, platform) }
  Pod::PodTarget.new(config.sandbox, build_type, user_build_configurations, archs, platform, specs, target_definitions,
                     file_accessors, scope_suffix, swift_version)
end

def fixture_aggregate_target(pod_targets = [], build_type = Pod::BuildType.static_library,
                             user_build_configurations = Pod::Target::DEFAULT_BUILD_CONFIGURATIONS, archs = [],
                             platform = Pod::Platform.new(:ios, '6.0'), target_definition = nil, user_project = nil,
                             user_target_uuids = [])
  target_definition ||= pod_targets.flat_map(&:target_definitions).first || fixture_target_definition
  Pod::AggregateTarget.new(config.sandbox, build_type, user_build_configurations, archs, platform,
                           target_definition, config.sandbox.root.dirname, user_project, user_target_uuids,
                           'Release' => pod_targets)
end

#-----------------------------------------------------------------------------#

SpecHelper::Fixture.fixture('banana-lib') # ensure it exists
SpecHelper::Fixture.fixture('orange-framework')
