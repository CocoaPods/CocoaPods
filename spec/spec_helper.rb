require 'rubygems'
require 'mac_bacon'

ROOT = File.expand_path('../../', __FILE__)

$:.unshift File.join(ROOT, 'lib')
require 'cocoa_pods'

$:.unshift File.join(ROOT, 'spec')
require 'spec_helper/fixture'
require 'spec_helper/git'
require 'spec_helper/log'
require 'spec_helper/temporary_directory'

#TMP_DIR = SpecHelper::TemporaryDirectory.temporary_directory
#TMP_COCOA_PODS_DIR = File.join(TMP_DIR, 'cocoa-pods')

class Bacon::Context
  include Pod::Config::Mixin
end

Pod::Config.instance.repos_dir = SpecHelper.tmp_repos_path
