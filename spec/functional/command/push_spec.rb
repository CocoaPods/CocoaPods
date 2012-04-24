require File.expand_path('../../../spec_helper', __FILE__)

describe Pod::Command::Push do
  extend SpecHelper::Command
  extend SpecHelper::Git
  extend SpecHelper::TemporaryDirectory

  it "complains for wrong parameters" do
    lambda { run_command('push') }.should.raise Pod::Command::Help
    lambda { run_command('push', '--allow-warnings') }.should.raise Pod::Command::Help
    lambda { run_command('push', '--wrong-option') }.should.raise Pod::Command::Help
  end

  it "complains if it can't find the repo" do
    repo1 = add_repo('repo1', fixture('spec-repos/master'))
    Dir.chdir(fixture('banana-lib')) do
      lambda { run_command('push', 'repo2') }.should.raise Pod::Informative
    end
  end

  it "complains if it can't find a spec" do
    repo1 = add_repo('repo1', fixture('spec-repos/master'))
    lambda { run_command('push', 'repo1') }.should.raise Pod::Informative
  end

  it "it raises if the pod is not validated" do
    repo1 = add_repo('repo1', fixture('spec-repos/master'))
    git('repo1', 'checkout master') # checkout master, because the fixture is a submodule
    repo2 = add_repo('repo2', repo1.dir)
    git_config('repo2', 'remote.origin.url').should == (tmp_repos_path + 'repo1').to_s
    Dir.chdir(fixture('banana-lib')) do
     lambda { command('push', 'repo2', '--silent').run }.should.raise Pod::Informative
    end
    # (repo1.dir + 'BananaLib/1.0/BananaLib.podspec').read.should.include 'Added!'
  end

  before do
    # prepare the repos
    @upstream = add_repo('upstream', fixture('spec-repos/master'))
    git('upstream', 'checkout -b master') # checkout master, because the fixture is a submodule
    @local_repo = add_repo('local_repo', @upstream.dir)
    git_config('local_repo', 'remote.origin.url').should == (tmp_repos_path + 'upstream').to_s
    git('upstream', 'checkout -b no-master') # checkout no-master, to allow push in a non-bare repository

    # prepare the spec
    spec_fix = (fixture('spec-repos') + 'master/JSONKit/1.4/JSONKit.podspec').read
    spec_add = spec_fix.gsub(/https:\/\/github\.com\/johnezang\/JSONKit\.git/, fixture('integration/JSONKit').to_s)
    spec_add.gsub!(/'JSONKit'/, "'PushTest'")
    File.open(temporary_directory + 'JSONKit.podspec', 'w') {|f| f.write(spec_fix) }
    File.open(temporary_directory + 'PushTest.podspec', 'w') {|f| f.write(spec_add) }
  end

  it "refuses to push if the repo is not clean" do
    File.open(@local_repo.dir + 'README', 'w') {|f| f.write('Added!') }
    (@local_repo.dir + 'README').read.should.include 'Added!'
    cmd = command('push', 'local_repo')
    cmd.expects(:validate_podspec_files).returns(true)
    Dir.chdir(temporary_directory) { lambda { cmd.run }.should.raise Pod::Informative }

    git('upstream', 'checkout master') # checkout master, because the fixture is a submodule
    (@upstream.dir + 'PushTest/1.4/PushTest.podspec').should.not.exist?
  end

  it "sucessfully pushes a spec" do
    cmd = command('push', 'local_repo')
    cmd.expects(:validate_podspec_files).returns(true)
    Dir.chdir(temporary_directory) { cmd.run }

    cmd.output.should.include('[Add] PushTest (1.4)')
    cmd.output.should.include('[Fix] JSONKit (1.4)')
    git('upstream', 'checkout master') # checkout master, because the fixture is a submodule
    (@upstream.dir + 'PushTest/1.4/PushTest.podspec').read.should.include('PushTest')
  end
end
