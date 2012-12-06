require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::Push do
    extend SpecHelper::Command
    extend SpecHelper::TemporaryDirectory
    extend SpecHelper::TemporaryRepos

    before do
      config.repos_dir = SpecHelper.tmp_repos_path
    end

    it "requires a spec-repo name" do
      lambda { command('push').validate! }.should.raise CLAide::Help
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

    # TODO: the validation should not use the pod spec command
    xit "it raises if the specification doesn't validates" do
      repo_make('test_repo')
      Dir.chdir(temporary_directory) do
        spec = "Spec.new do |s|; s.name = 'Broken'; end"
        File.open('Broken.podspec',  'w') {|f| f.write(spec) }
        cmd = command('push', 'test_repo')
        cmd.expects(:validate_podspec_files).returns(true)
        e = lambda { cmd.run }.should.raise Pod::Informative
        e.message.should.match(/repo not clean/)
      end
    end

    #--------------------------------------#

    before do
      repo_make('upstream')
      repo_clone('upstream', 'local_repo')

      # prepare the spec
      spec = (fixture('spec-repos') + 'master/JSONKit/1.4/JSONKit.podspec').read
      spec_fix = spec.gsub(/https:\/\/github\.com\/johnezang\/JSONKit\.git/, fixture('integration/JSONKit').to_s)
      spec_add = spec.gsub(/'JSONKit'/, "'PushTest'")
      File.open(temporary_directory + 'JSONKit.podspec',  'w') {|f| f.write(spec_fix) }
      File.open(temporary_directory + 'PushTest.podspec', 'w') {|f| f.write(spec_add) }
    end

    it "refuses to push if the repo is not clean" do
      repo_make_readme_change('local_repo', 'dirty')
      Dir.chdir(temporary_directory) do
        cmd = command('push', 'local_repo')
        cmd.expects(:validate_podspec_files).returns(true)
        e = lambda { cmd.run }.should.raise Pod::Informative
        e.message.should.match(/repo not clean/)
      end
      (repo_path('upstream') + 'PushTest/1.4/PushTest.podspec').should.not.exist?
    end

    it "sucessfully pushes a spec" do
      cmd = command('push', 'local_repo')
      Dir.chdir(repo_path 'upstream') { `git checkout -b tmp_for_push -q` }
      cmd.expects(:validate_podspec_files).returns(true)
      Dir.chdir(temporary_directory) { cmd.run }

      Pod::UI.output.should.include('[Add] PushTest (1.4)')
      Pod::UI.output.should.include('[Add] JSONKit (1.4)')
      # TODO check the commit messages
      # Pod::UI.output.should.include('[Fix] JSONKit (1.4)')

      Dir.chdir(repo_path 'upstream') { `git checkout master -q` }
      (repo_path('upstream') + 'PushTest/1.4/PushTest.podspec').read.should.include('PushTest')
    end
  end
end
