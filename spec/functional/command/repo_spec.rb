require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::Repo do
    describe "In general" do
      extend SpecHelper::Command
      extend SpecHelper::TemporaryRepos

      before do
        set_up_test_repo
        config.repos_dir = SpecHelper.tmp_repos_path
      end

      it "updates a repository" do
        upstream = SpecHelper.temporary_directory + 'upstream'
        FileUtils.cp_r(test_repo_path, upstream)
        Dir.chdir(test_repo_path) do
          `git remote add origin #{upstream}`
          `git remote -v`
          `git fetch -q`
          `git branch --set-upstream-to=origin/master master`
        end
        lambda { command('repo', 'update').run }.should.not.raise
      end

      it "lints a repository" do
        repo = fixture('spec-repos/test_repo').to_s
        lambda { run_command('repo', 'lint', repo) }.should.not.raise
      end

      it "adds a spec-repo" do
        run_command('repo', 'add', 'private', test_repo_path)
        Dir.chdir(config.repos_dir + 'private') do
          `git config --get remote.origin.url`.chomp.should == test_repo_path.to_s
        end
      end

      it "adds a spec-repo with a specified branch" do
        repo1 = repo_make('repo1')
        Dir.chdir(repo1) do
          `git checkout -b my-branch >/dev/null 2>&1`
          `git checkout master >/dev/null 2>&1`
        end
        repo2 = command( 'repo' ,'add', 'repo2', repo1.to_s, 'my-branch')
        repo2.run
        Dir.chdir(repo2.dir) { `git symbolic-ref HEAD` }.should.include? 'my-branch'
      end

      it "updates a spec-repo" do
        repo1 = repo_make('repo1')
        repo2 = repo_clone('repo1', 'repo2')
        repo_make_readme_change(repo1, 'Updated')
        Dir.chdir(repo1) {`git commit -a -m "Update"`}
        run_command('repo', 'update', 'repo2')
        (repo2 + 'README').read.should.include 'Updated'
      end

      it "removes a spec-repo" do
        upstream = SpecHelper.temporary_directory + 'upstream'
        FileUtils.cp_r(test_repo_path, upstream)
        lambda { run_command('repo', 'remove', upstream) }.should.not.raise
        File.directory?(test_repo_path + upstream).should.be.false?
      end
    end
  end
end
