require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Command::Repo::Add do
    extend SpecHelper::Command
    extend SpecHelper::TemporaryRepos

    before do
      set_up_test_repo
      config.repos_dir = SpecHelper.tmp_repos_path
    end

    it 'adds a spec-repo' do
      run_command('repo', 'add', 'private', test_repo_path)
      Dir.chdir(config.repos_dir + 'private') do
        `git config --get remote.origin.url`.chomp.should == test_repo_path.to_s
      end
    end

    it 'adds a spec-repo with a name that starts with a -' do
      run_command('repo', 'add', '-tmp', test_repo_path)
      Dir.chdir(config.repos_dir + '-tmp') do
        `git config --get remote.origin.url`.chomp.should == test_repo_path.to_s
      end
    end

    it 'adds a spec-repo with a specified branch' do
      repo1 = repo_make('repo1')
      Dir.chdir(repo1) do
        `git checkout -b my-branch >/dev/null 2>&1`
        `git checkout master >/dev/null 2>&1`
      end
      repo2 = command('repo', 'add', 'repo2', repo1.to_s, 'my-branch')
      repo2.run
      Dir.chdir(repo2.dir) { `git symbolic-ref HEAD` }.should.include? 'my-branch'
    end

    it 'raises an informative error when the repos directory fails to be created' do
      repos_dir = config.repos_dir
      def repos_dir.mkpath
        raise SystemCallError, 'Operation not permitted'
      end
      e = lambda { run_command('repo', 'add', 'private', test_repo_path) }.should.raise Informative
      e.message.should.match /Could not create '#{tmp_repos_path}', the CocoaPods repo cache directory./
    end

    it 'raises an informative error when attempting to add `trunk`' do
      master = command('repo', 'add', 'trunk', 'https://github.com/foo/bar.git')
      should.raise(Informative) { master.validate! }.message.should.
        include("Repo name `trunk` is reserved for CocoaPods' main spec repo accessed via CDN.")
    end
  end
end
