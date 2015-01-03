require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Command::Repo::List do
    extend SpecHelper::Command
    extend SpecHelper::TemporaryRepos

    before do
      set_up_test_repo
      config.repos_dir = SpecHelper.tmp_repos_path
    end

    it 'lists a repository' do
      lambda { run_command('repo', 'list') }.should.not.raise
    end

    it 'lists a repository (checking the output)' do
      config.repos_dir = fixture('spec-repos')
      output = run_command('repo', 'list')
      output.should.include? '- Type:'
    end

    it 'only prints a count when invoked with --count-only' do
      config.repos_dir = fixture('spec-repos')
      output = run_command('repo', 'list', '--count-only')
      output.should.include? 'repo'
      output.should.not.include? '- Type:'
    end
  end
end
