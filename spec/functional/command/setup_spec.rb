require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::Setup do
    extend SpecHelper::Command

    extend SpecHelper::TemporaryRepos

    before do
      config.repos_dir = SpecHelper.tmp_repos_path
    end

    it 'returns the read only URL of the `master` spec-repo' do
      cmd = Command::Setup.new(argv)
      cmd.url.should == 'https://github.com/CocoaPods/Specs.git'
    end

    before do
      set_up_test_repo
      Command::Setup.stubs(:read_only_url).returns(test_repo_path.to_s)
      config.repos_dir = SpecHelper.temporary_directory
    end

    it 'runs with correct parameters' do
      lambda { run_command('setup') }.should.not.raise
    end

    it 'creates the local spec-repos directory and creates a clone of the `master` repo' do
      output = run_command('setup')
      output.should.include 'Setup completed'
      url = Dir.chdir(config.repos_dir + 'master') { `git config --get remote.origin.url`.chomp }
      url.should == test_repo_path.to_s
    end

    it 'creates a shallow clone of the `master` repo by default' do
      Dir.chdir(test_repo_path) do
        `echo 'touch' > touch && git add touch && git commit -m 'updated'`
      end
      # Need to use file:// to test local use of --depth=1
      Command::Setup.stubs(:read_only_url).returns("file://#{test_repo_path}")
      run_command('setup')
      Dir.chdir(config.repos_dir + 'master') do
        `git log --pretty=oneline`.strip.split("\n").size.should == 1
      end
    end

    it 'creates a full clone of the `master` repo if requested' do
      Dir.chdir(test_repo_path) do
        `echo 'touch' > touch && git add touch && git commit -m 'updated'`
      end
      run_command('setup', '--no-shallow')
      Dir.chdir(config.repos_dir + 'master') do
        `git log --pretty=oneline`.strip.split("\n").size.should > 1
      end
    end
  end
end
