require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Command::Repo::AddCDN do
    extend SpecHelper::Command
    extend SpecHelper::TemporaryRepos
    TEST_REPO_URL = 'https://localhost:4321/'.freeze

    before do
      config.repos_dir = SpecHelper.tmp_repos_path
    end

    it 'adds a spec-repo' do
      run_command('repo', 'add-cdn', 'private', TEST_REPO_URL)
      Dir.chdir(config.repos_dir + 'private') do
        File.read('.url').should == TEST_REPO_URL
      end
    end

    it 'raises an informative error when the repos directory fails to be created' do
      Pathname.any_instance.expects(:mkpath).raises(SystemCallError, 'Operation not permitted')
      e = lambda { run_command('repo', 'add-cdn', 'private', TEST_REPO_URL) }.should.raise Informative
      e.message.should.match /Could not create '#{tmp_repos_path}', the CocoaPods repo cache directory./
    end
  end
end
