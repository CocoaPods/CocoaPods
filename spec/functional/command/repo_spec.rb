require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::Repo do
    describe "In general" do
      extend SpecHelper::Command
      extend SpecHelper::TemporaryDirectory
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
          `git branch --set-upstream master origin/master`
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
    end

    describe "CocoaPods version" do
      extend SpecHelper::Command
      extend SpecHelper::TemporaryDirectory
      extend SpecHelper::TemporaryRepos

      require 'yaml'

      before do
        config.repos_dir = SpecHelper.tmp_repos_path
        @repo = repo_make('repo1')
      end

      def write_version_file(hash)
        yaml = YAML.dump(hash)
        @versions_file = tmp_repos_path + "repo1/CocoaPods-version.yml"
        File.open(@versions_file, 'w') {|f| f.write(yaml) }
      end

      it "it doesn't requires CocoaPods-version.yml" do
        cmd = command('repo', 'update')
        lambda { cmd.check_versions(@repo) }.should.not.raise
      end

      it "runs with a compatible repo" do
        write_version_file({'min' => "0.0.1"})
        cmd = command('repo', 'update')
        lambda { cmd.check_versions(@repo) }.should.not.raise
      end

      it "raises if a repo is not compatible" do
        write_version_file({'min' => "999.0.0"})
        cmd = command('repo', 'update')
        lambda { cmd.check_versions(@repo) }.should.raise Informative
      end

      it "informs about a higher known CocoaPods version" do
        write_version_file({'last' => "999.0.0"})
        cmd = command('repo', 'update')
        cmd.check_versions(@repo)
        UI.output.should.include "Cocoapods 999.0.0 is available"
      end

      it "has a class method that returns if a repo is supported" do
        write_version_file({'min' => "999.0.0"})
        Command::Repo.compatible?('repo1').should == false

        write_version_file({'min' => "0.0.1"})
        Command::Repo.compatible?('repo1').should == true
      end
    end
  end
end
