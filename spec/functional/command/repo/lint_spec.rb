require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Command::Repo::Lint do
    extend SpecHelper::Command
    extend SpecHelper::TemporaryRepos

    before do
      set_up_test_repo
      config.repos_dir = SpecHelper.tmp_repos_path
      require 'rest'
      ::REST.stubs(:head => stub(:success? => true))
    end

    it 'lints a repository' do
      repo = fixture('spec-repos/test_repo').to_s
      lambda { run_command('repo', 'lint', repo) }.should.not.raise
    end
  end
end
