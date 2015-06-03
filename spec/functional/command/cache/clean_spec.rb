require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Command::Cache::Clean do
    extend SpecHelper::Command
    extend SpecHelper::TemporaryCache

    before do
      SpecHelper::TemporaryCache.set_up_test_cache
      config.cache_root = SpecHelper::TemporaryCache.tmp_cache_path
    end

    it 'requires --all if no name given' do
      e = lambda { run_command('cache', 'clean') }.should.raise CLAide::Help
      e.message.should.match(/specify a pod name or use the --all flag/)
    end

    it 'asks the pod to clean when multiple matches' do
      e = lambda { run_command('cache', 'clean', 'AFNetworking') }.should.raise Pod::Informative
      e.message.should == '[!] 0 is invalid [1-2]'
    end

    it 'clean all matching pods when given a name and --all' do
      run_command('cache', 'clean', '--all', 'AFNetworking')
      remaining_occurences = Dir.glob(tmp_cache_path + '**/AFNetworking')
      # We only clean files (so there may still be some empty dirs), so check for files only
      remaining_occurences.select { |f| File.file?(f) }.should == []
    end

    it 'clean all pods when given --all' do
      run_command('cache', 'clean', '--all')
      Dir.glob(tmp_cache_path + '**/*').should == []
    end

    it 'warns when no matching pod found in the cache' do
      output = run_command('cache', 'clean', 'non-existing-pod')
      output.should.match(/No cache for pod/)
    end
  end
end
