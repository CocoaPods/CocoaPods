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

require 'vcr'
require 'webmock'

VCR.configure do |c|
  # Namespace the fixture by the Ruby version, because different Ruby versions
  # can lead to different ways the data is interpreted.
  c.cassette_library_dir = (ROOT + "spec/fixtures/vcr/#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}").to_s
  c.hook_into :webmock # or :fakeweb
  c.allow_http_connections_when_no_cassette = true
end
