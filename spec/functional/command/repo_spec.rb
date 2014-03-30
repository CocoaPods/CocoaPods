require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::Repo do
    describe Command::Repo::Update do
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

      it "updates a spec-repo" do
        repo1 = repo_make('repo1')
        repo2 = repo_clone('repo1', 'repo2')
        repo_make_readme_change(repo1, 'Updated')
        Dir.chdir(repo1) {`git commit -a -m "Update"`}
        run_command('repo', 'update', 'repo2')
        (repo2 + 'README').read.should.include 'Updated'
      end
    end

    describe Command::Repo::Lint do
      extend SpecHelper::Command
      extend SpecHelper::TemporaryRepos

      before do
        set_up_test_repo
        config.repos_dir = SpecHelper.tmp_repos_path
        ::REST.stubs(:head => stub(:success? => true))
      end

      it "lints a repository" do
        repo = fixture('spec-repos/test_repo').to_s
        lambda { run_command('repo', 'lint', repo) }.should.not.raise
      end
    end

    describe Command::Repo::Add do
      extend SpecHelper::Command
      extend SpecHelper::TemporaryRepos

      before do
        set_up_test_repo
        config.repos_dir = SpecHelper.tmp_repos_path
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

      it "adds a spec-repo by creating a shallow clone" do
        Dir.chdir(test_repo_path) do
          `echo 'touch' > touch && git add touch && git commit -m 'updated'`
        end
        # Need to use file:// to test local use of --depth=1
        run_command('repo', 'add', 'private', '--shallow', "file://#{test_repo_path}")
        Dir.chdir(config.repos_dir + 'private') do
          `git log --pretty=oneline`.strip.split("\n").size.should == 1
        end
      end
    end

    describe Command::Repo::Remove do
      extend SpecHelper::Command
      extend SpecHelper::TemporaryRepos

      before do
        set_up_test_repo
        config.repos_dir = SpecHelper.tmp_repos_path
      end

      it "complains when a repository name is missing" do
        lambda { run_command('repo', 'remove') }.should.raise CLAide::Help
      end

      it "complains if the repository doesn't exist" do
        lambda { run_command('repo', 'remove', 'nonexistant') }.should.raise CLAide::Help
      end

      it "complains if we do not have permission" do
        File.stubs(:writable?).returns(false)
        upstream = SpecHelper.temporary_directory + 'upstream'
        FileUtils.cp_r(test_repo_path, upstream)
        lambda { run_command('repo', 'remove', upstream) }.should.raise CLAide::Help
        FileUtils.rm_rf(upstream)
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
