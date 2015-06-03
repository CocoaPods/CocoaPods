require File.expand_path('../../../../spec_helper', __FILE__)
require 'yaml'

module Pod
  describe Command::Cache::List do
    extend SpecHelper::Command
    extend SpecHelper::TemporaryCache

    before do
      SpecHelper::TemporaryCache.set_up_test_cache
      config.cache_root = SpecHelper::TemporaryCache.tmp_cache_path
    end

    describe 'lists the whole content of the cache as YAML' do
      it 'shows the long form without --short' do
        output = run_command('cache', 'list')
        yaml = YAML.load(output)
        yaml.should == SpecHelper::TemporaryCache.test_cache_yaml(false)
      end

      it 'shows the short form with --short' do
        output = run_command('cache', 'list', '--short')
        yaml = YAML.load(output)
        yaml.should == SpecHelper::TemporaryCache.test_cache_yaml(true)
      end
    end

    describe 'lists only the cache content for the requested pod as YAML' do
      it 'shows the long form without --short' do
        output = run_command('cache', 'list', 'AFNetworking')
        yaml = YAML.load(output)
        yaml.should == SpecHelper::TemporaryCache.test_cache_yaml(false).select do |key, _|
          key == 'AFNetworking'
        end
      end

      it 'shows the short form with --short' do
        run_command('cache', 'list', '--short', 'bananalib')
        output = run_command('cache', 'list', 'AFNetworking')
        yaml = YAML.load(output)
        yaml.should == SpecHelper::TemporaryCache.test_cache_yaml(false).select do |key, _|
          ['AFNetworking', '$CACHE_ROOT'].include?(key)
        end
      end
    end
  end
end
