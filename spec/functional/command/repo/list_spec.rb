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

    it 'shows the path to the spec repository' do
      output = run_command('repo', 'list')
      output.should.include? "- Path: #{repo_path('master')}"
    end

    it 'shows unknown as the branch when there is no branch for git repositories' do
      path = repo_path(name)
      path.mkpath
      Pod::Executable.capture_command!('git', %w(init), :chdir => path)

      output = run_command('repo', 'list')
      output.should.include? 'git (unknown)'
    end

    describe 'with a git based spec repository with a remote' do
      before do
        config.repos_dir = tmp_repos_path

        Pod::Executable.capture_command!('git', %w(remote add origin https://github.com/apiaryio/Specs),
                                         :chdir => repo_make('apiary'))
      end

      it 'shows the current git branch configuration' do
        output = run_command('repo', 'list')
        output.should.include? '- Type: git (master)'
      end

      it 'shows the git URL (when an upstream is not configured)' do
        output = run_command('repo', 'list')
        output.should.include? '- URL:  https://github.com/apiaryio/Specs'
      end
    end
  end
end
