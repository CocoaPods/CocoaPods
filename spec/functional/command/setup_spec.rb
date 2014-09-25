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

    it 'returns the push URL of the `master` spec-repo' do
      config.silent = true
      cmd = Command::Setup.new(argv('--push'))
      cmd.url.should == 'git@github.com:CocoaPods/Specs.git'
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
      output.should.not.include 'push'
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

    it 'creates a full clone of the `master` repo when push access is requested' do
      Dir.chdir(test_repo_path) do
        `echo 'touch' > touch && git add touch && git commit -m 'updated'`
      end
      # Need to use file:// to test local use of --depth=1
      Command::Setup.stubs(:read_write_url).returns("file://#{test_repo_path}")
      cmd = run_command('setup', '--push')
      Dir.chdir(config.repos_dir + 'master') do
        `git log --pretty=oneline`.strip.split("\n").size.should > 1
      end
    end

    it 'preserves push access for the `master` repo' do
      output = run_command('setup')
      output.should.not.include 'push'
      Dir.chdir(config.repos_dir + 'master') { `git remote set-url origin git@github.com:CocoaPods/Specs.git` }
      command('setup').url.should == 'git@github.com:CocoaPods/Specs.git'
    end

    before do
      FileUtils.rm_rf(test_repo_path)
      set_up_old_test_repo
      config.repos_dir = SpecHelper.temporary_directory + 'cocoapods/repos'
      Command::Setup.any_instance.stubs(:old_master_repo_dir).returns(SpecHelper.temporary_directory + 'cocoapods/master')
    end

    it 'migrates repos from the old directory structure to the new one' do
      source = SpecHelper.temporary_directory + 'cocoapods/master'
      target = config.repos_dir + 'master'

      source.should.exist?
      target.should.not.exist?

      output = run_command('setup')

      source.should.not.exist?
      target.should.exist?
    end

  end
end
