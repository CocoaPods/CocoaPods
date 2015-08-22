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

RSpec.configure do |config|
  config.include SpecHelper::Fixture
  config.include SpecHelper::Command
  config.include Pod::Config::Mixin
  def skip_xcodebuild?
    ENV['SKIP_XCODEBUILD']
  end

  def temporary_directory
    SpecHelper.temporary_directory
  end

  config.mock_with :rspec do |mocks|
    mocks.syntax = :should

    ::Object.send(:define_method, :stubs) { |*args, &blk| stub(*args, &blk) }
    ::Object.send(:define_method, :expects) { |*args, &blk| should_receive(*args, &blk) }
    ::RSpec::Mocks::MessageExpectation.send(:define_method, :returns) { |*args, &blk| and_return(*args, &blk) }
    ::RSpec::Mocks::AnyInstance::StubChain.send(:define_method, :returns) { |*args, &blk| and_return(*args, &blk) }
    ::RSpec::Mocks::AnyInstance::PositiveExpectationChain.send(:define_method, :returns) { |*args, &blk| and_return(*args, &blk) }
    ::RSpec::Matchers::BuiltIn::OperatorMatcher.send(:define_method, :raise) do |*args, &blk|
      matcher = ::RSpec::Matchers::BuiltIn::RaiseError.new(*args, &blk)
      method = is_a?(::RSpec::Matchers::BuiltIn::NegativeOperatorMatcher) ? :should_not : :should
      @actual.send(method, matcher)
      matcher.instance_variable_get(:@actual_error)
    end
    ::RSpec::Matchers::BuiltIn::OperatorMatcher.send(:define_method, :not) { ::RSpec::Matchers::BuiltIn::NegativeOperatorMatcher.new(@actual) }
    ::RSpec::Matchers::BuiltIn::OperatorMatcher.send(:include, ::RSpec::Matchers)
    class BeShim
      include ::RSpec::Matchers
      def initialize(actual, should_method)
        @actual = actual
        @should_method = should_method
      end
      def method_missing(m, *args, &blk)
        m = m.to_s.chomp('?').to_sym
        matcher = case m
        when :true
          be_truthy
        when :false
          be_falsey
        when :nil
          be_nil
        when :kind_of
          be_a_kind_of(*args)
        else
          ::RSpec::Matchers::BuiltIn::BePredicate.new(:"be_#{m}", *args, &blk)
        end
        @actual.send(@should_method, matcher)
      end
    end

    ::RSpec::Matchers::BuiltIn::OperatorMatcher.send(:define_method, :be) do
      method = is_a?(::RSpec::Matchers::BuiltIn::NegativeOperatorMatcher) ? :should_not : :should
      BeShim.new(@actual, method)
    end

    class ::RSpec::Matchers::BuiltIn::OperatorMatcher
      alias_method :cp_method_missing, :method_missing
      def method_missing(m, *args, &blk)
        wo = m.to_s.chomp('?').to_sym
        if wo == m
          cp_method_missing(m, *args, &blk)
        else
          send(wo, *args, &blk)
        end
      end
    end
    ::RSpec::Core::ExampleGroup.send(:define_method, :stub) { |*args, &blk| double(*args, &blk) }
    ::RSpec::Core::ExampleGroup.send(:define_method, :mock) { |*args, &blk| double(*args, &blk) }
    ::RSpec::Core::ExampleGroup.send(:define_method, :should) do |*args, &blk|
      d = double()
      def d.raise(*args, &blk);
        matcher = ::RSpec::Matchers::BuiltIn::RaiseError.new(*args)
        method = @not ? :should_not : :should
        blk.send(method, matcher)
        matcher.instance_variable_get(:@actual_error)
      end
      def d.not
        @not = true
        self
      end
      d
    end
  end

  config.expect_with(:rspec) { |c| c.syntax = :should }
end

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
  Pod::Podfile::TargetDefinition.new(name, Pod::Podfile.new, 'name' => name, 'platform' => platform)
end

def fixture_pod_target(spec_or_name, target_definition = nil)
  spec = spec_or_name.is_a?(Pod::Specification) ? spec_or_name : fixture_spec(spec_or_name)
  target_definition ||= fixture_target_definition
  target_definition.store_pod(spec.name)
  Pod::PodTarget.new([spec], [target_definition], config.sandbox).tap do |pod_target|
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
