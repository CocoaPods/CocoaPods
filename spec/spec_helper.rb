require 'rubygems'
require 'bacon'
require 'mocha-on-bacon'

require 'pathname'
ROOT = Pathname.new(File.expand_path('../../', __FILE__))

$:.unshift File.expand_path('../../external/Xcodeproj/ext', __FILE__)
$:.unshift File.expand_path('../../external/Xcodeproj/lib', __FILE__)
$:.unshift((ROOT + 'lib').to_s)
require 'cocoapods'

$:.unshift((ROOT + 'spec').to_s)
require 'spec_helper/fixture'
require 'spec_helper/git'
require 'spec_helper/temporary_directory'

context_class = defined?(BaconContext) ? BaconContext : Bacon::Context
context_class.class_eval do
  include Pod::Config::Mixin

  include SpecHelper::Fixture

  def argv(*argv)
    Pod::Command::ARGV.new(argv)
  end
end

config = Pod::Config.instance
config.silent = true
config.repos_dir = SpecHelper.tmp_repos_path

require 'tmpdir'

def temporary_sandbox
  Pod::Sandbox.new(Pathname.new(Dir.mktmpdir + "/Pods"))
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
