require 'rubygems'
require 'mac_bacon'

require 'pathname'
ROOT = Pathname.new(File.expand_path('../../', __FILE__))

gem 'activesupport', '~> 3.1.1'
$:.unshift((ROOT + 'lib').to_s)
require 'cocoapods'

$:.unshift((ROOT + 'spec').to_s)
require 'spec_helper/fixture'
require 'spec_helper/git'
require 'spec_helper/log'
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

class Pod::Source
  def self.reset!
    @sources = nil
  end
end

class Pod::Spec::Set
  def self.reset!
    @sets = nil
  end
end
