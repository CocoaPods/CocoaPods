require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::Push do
    extend SpecHelper::Command
    extend SpecHelper::TemporaryRepos

    before do
      config.repos_dir = SpecHelper.tmp_repos_path
    end

    it "complains if it can't find the repo" do
      Dir.chdir(fixture('banana-lib')) do
        cmd = command('push', 'missing_repo')
        cmd.expects(:validate_podspec_files).returns(true)
        e = lambda { cmd.run }.should.raise Informative
        e.message.should.match(/repo not found/)
      end
    end

    it "complains if it can't find a spec" do
      repo_make('test_repo')
      e = lambda { run_command('push', 'test_repo') }.should.raise Pod::Informative
      e.message.should.match(/Couldn't find any .podspec/)
    end

    it "it raises if the specification doesn't validate" do
      repo_make('test_repo')
      Dir.chdir(temporary_directory) do
        spec = "Spec.new do |s|; s.name = 'Broken'; s.version = '1.0' end"
        File.open('Broken.podspec',  'w') {|f| f.write(spec) }
        cmd = command('push', 'test_repo')
        Validator.any_instance.stubs(:validated?).returns(false)

        e = lambda { cmd.run }.should.raise Pod::Informative
        e.message.should.match(/Broken.podspec.*does not validate/)
      end
    end

    #--------------------------------------#

    before do
      set_up_test_repo
      config.repos_dir = SpecHelper.tmp_repos_path

      @upstream = SpecHelper.temporary_directory + 'upstream'
      FileUtils.cp_r(test_repo_path, @upstream)
      Dir.chdir(test_repo_path) do
        `git remote add origin #{@upstream}`
        `git remote -v`
        `git fetch -q`
        `git branch --set-upstream master origin/master`
      end

      # prepare the spec
      spec = (fixture('spec-repos') + 'master/JSONKit/1.4/JSONKit.podspec').read
      spec_fix = spec.gsub(/https:\/\/github\.com\/johnezang\/JSONKit\.git/, fixture('integration/JSONKit').to_s)
      spec_add = spec.gsub(/'JSONKit'/, "'PushTest'")
      File.open(temporary_directory + 'JSONKit.podspec',  'w') {|f| f.write(spec_fix) }
      File.open(temporary_directory + 'PushTest.podspec', 'w') {|f| f.write(spec_add) }
    end

    it "refuses to push if the repo is not clean" do
      Dir.chdir(test_repo_path) do
        `touch DIRTY_FILE`
      end
      cmd = command('push', 'master')
      cmd.expects(:validate_podspec_files).returns(true)
      e = lambda { cmd.run }.should.raise Pod::Informative
      e.message.should.match(/repo.*not clean/)
      (@upstream + 'PushTest/1.4/PushTest.podspec').should.not.exist?
    end

    it "successfully pushes a spec" do

      cmd = command('push', 'master')
      Dir.chdir(@upstream) { `git checkout -b tmp_for_push -q` }
      cmd.expects(:validate_podspec_files).returns(true)
      Dir.chdir(temporary_directory) { cmd.run }
      Pod::UI.output.should.include('[Add] PushTest (1.4)')
      Pod::UI.output.should.include('[Fix] JSONKit (1.4)')
      Dir.chdir(@upstream) { `git checkout master -q` }
      (@upstream + 'PushTest/1.4/PushTest.podspec').read.should.include('PushTest')
    end
  end
end
