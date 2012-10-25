require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::Push do
    extend SpecHelper::Command
    extend SpecHelper::TemporaryDirectory
    extend SpecHelper::TemporaryRepos

    before do
      config.repos_dir = SpecHelper.tmp_repos_path
    end

    def master_repo
      fixture('spec-repos/master')
    end

    it "requires a spec-repo name" do
      lambda { command('push').validate! }.should.raise Command::Help
    end

    it "complains if it can't find the repo" do
      repo1 = add_repo('repo1', master_repo)
      Dir.chdir(fixture('banana-lib')) do
        lambda { run_command('push', 'repo2') }.should.raise Informative
      end
    end

    it "complains if it can't find a spec" do
      repo1 = add_repo('repo1', master_repo)
      lambda { run_command('push', 'repo1') }.should.raise Informative
    end

    it "it raises if the pod is not validated" do
      repo1 = add_repo('repo1', master_repo)
      repo2 = add_repo('repo2', repo1.dir)
      git_config('repo2', 'remote.origin.url').should == (tmp_repos_path + 'repo1').to_s
      Dir.chdir(fixture('banana-lib')) do
        lambda { run_command('push', 'repo2', '--silent') }.should.raise Informative
      end
      # (repo1.dir + 'BananaLib/1.0/BananaLib.podspec').read.should.include 'Added!'
    end

    before do
      # prepare the repos
      @upstream = add_repo('upstream', master_repo)
      @local_repo = add_repo('local_repo', @upstream.dir)
      git_config('local_repo', 'remote.origin.url').should == (tmp_repos_path + 'upstream').to_s

      # prepare the spec
      spec = (fixture('spec-repos') + 'master/JSONKit/1.4/JSONKit.podspec').read
      spec_fix = spec.gsub(/https:\/\/github\.com\/johnezang\/JSONKit\.git/, fixture('integration/JSONKit').to_s)
      spec_add = spec.gsub(/'JSONKit'/, "'PushTest'")
      File.open(temporary_directory + 'JSONKit.podspec', 'w') {|f| f.write(spec_fix) }
      File.open(temporary_directory + 'PushTest.podspec', 'w') {|f| f.write(spec_add) }
    end

    it "refuses to push if the repo is not clean" do
      File.open(@local_repo.dir + 'README', 'w') {|f| f.write('Added!') }
      (@local_repo.dir + 'README').read.should.include 'Added!'
      cmd = command('push', 'local_repo')
      cmd.expects(:validate_podspec_files).returns(true)
      Dir.chdir(temporary_directory) { lambda { cmd.run }.should.raise Informative }

      (@upstream.dir + 'PushTest/1.4/PushTest.podspec').should.not.exist?
    end

    it "sucessfully pushes a spec" do
      git('upstream', 'checkout master') # checkout master, to allow push in a non-bare repository
      cmd = command('push', 'local_repo')
      cmd.expects(:validate_podspec_files).returns(true)
      Dir.chdir(temporary_directory) { cmd.run }

      UI.output.should.include('[Add] PushTest (1.4)')
      UI.output.should.include('[Fix] JSONKit (1.4)')

      git('upstream', 'checkout test') # checkout because test because is it the branch used in the specs.
      (@upstream.dir + 'PushTest/1.4/PushTest.podspec').read.should.include('PushTest')
    end
  end
end
