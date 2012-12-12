require 'rubygems'
require 'bundler/setup'

require 'bacon'
require 'mocha-on-bacon'
Bacon.summary_at_exit

require 'pathname'
ROOT = Pathname.new(File.expand_path('../../', __FILE__))

$:.unshift((ROOT + 'lib').to_s)
require 'cocoapods'

$:.unshift((ROOT + 'spec').to_s)
require 'spec_helper/bacon'
require 'spec_helper/command'
require 'spec_helper/fixture'
require 'spec_helper/github'
require 'spec_helper/temporary_directory'
require 'spec_helper/temporary_repos'
require 'spec_helper/user_interface'
require 'spec_helper/pre_flight'

ENV['SKIP_SETUP'] = 'true'
if ENV['SKIP_XCODEBUILD'].nil? && `which xcodebuild`.strip.empty?
  ENV['SKIP_XCODEBUILD'] = 'true'
end

require 'claide'

module Bacon
  class Context
    include Pod::Config::Mixin
    include SpecHelper::Fixture
    include SpecHelper::Command

    def skip_xcodebuild?
      ENV['SKIP_XCODEBUILD']
    end
  end
end

config = Pod::Config.instance
config.silent       = true
config.repos_dir    = SpecHelper.tmp_repos_path
config.project_root = SpecHelper.temporary_directory
Pod::Specification::Set::Statistics.instance.cache_file = nil

require 'tmpdir'

# TODO why is this no longer using SpecHelper::TemporaryDirectory ?
def temporary_sandbox
  Pod::Sandbox.new(Pathname.new(Dir.mktmpdir + "/Pods"))
  #Pod::Sandbox.new(temporary_directory + "Pods")
end

def fixture_spec(name)
  file = SpecHelper::Fixture.fixture(name)
  Pod::Specification.from_file(file)
end

def copy_fixture_to_pod(name, pod)
  path = SpecHelper::Fixture.fixture(name)
  FileUtils.cp_r(path, pod.root)
end

SpecHelper::Fixture.fixture('banana-lib') # ensure it exists

require "active_support/core_ext/string/strip"
