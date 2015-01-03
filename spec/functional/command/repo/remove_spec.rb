require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Command::Repo::Remove do
    extend SpecHelper::Command
    extend SpecHelper::TemporaryRepos

    before do
      set_up_test_repo
      config.repos_dir = SpecHelper.tmp_repos_path
    end

    it 'complains when a repository name is missing' do
      lambda { run_command('repo', 'remove') }.should.raise CLAide::Help
    end

    it "complains if the repository doesn't exist" do
      lambda { run_command('repo', 'remove', 'nonexistant') }.should.raise CLAide::Help
    end

    it 'complains if we do not have permission' do
      File.stubs(:writable?).returns(false)
      upstream = SpecHelper.temporary_directory + 'upstream'
      FileUtils.cp_r(test_repo_path, upstream)
      lambda { run_command('repo', 'remove', upstream) }.should.raise CLAide::Help
      FileUtils.rm_rf(upstream)
    end

    it 'removes a spec-repo' do
      upstream = SpecHelper.temporary_directory + 'upstream'
      FileUtils.cp_r(test_repo_path, upstream)
      lambda { run_command('repo', 'remove', upstream) }.should.not.raise
      File.directory?(test_repo_path + upstream).should.be.false?
    end
  end
end
