require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Command do
    it 'returns the proper command class' do
      Command.parse(%w(install         )).should.be.instance_of Command::Install
      Command.parse(%w(list            )).should.be.instance_of Command::List
      Command.parse(%w(outdated        )).should.be.instance_of Command::Outdated
      Command.parse(%w(repo            )).should.be.instance_of Command::Repo::List
      Command.parse(%w(repo add        )).should.be.instance_of Command::Repo::Add
      Command.parse(%w(repo lint       )).should.be.instance_of Command::Repo::Lint
      Command.parse(%w(repo list       )).should.be.instance_of Command::Repo::List
      Command.parse(%w(repo update     )).should.be.instance_of Command::Repo::Update
      Command.parse(%w(repo remove     )).should.be.instance_of Command::Repo::Remove
      Command.parse(%w(repo push --help)).should.be.instance_of Command::Repo::Push
      Command.parse(%w(setup           )).should.be.instance_of Command::Setup
      Command.parse(%w(spec create     )).should.be.instance_of Command::Spec::Create
      Command.parse(%w(spec lint       )).should.be.instance_of Command::Spec::Lint
      Command.parse(%w(init            )).should.be.instance_of Command::Init
      Command.parse(%w(env             )).should.be.instance_of Command::Env
    end

    describe 'git version validation' do
      valid_git_versions = [
        Gem::Version.new('1.8.5'),
        Gem::Version.new('2.10.2'),
        Gem::Version.new('2.8.4'),
      ]

      invalid_git_versions = [
        Gem::Version.new('1.7.4'),
        Gem::Version.new('0.2.9'),
      ]

      valid_git_versions.each do |version|
        it "does not raise an error for version #{version}" do
          Command.expects(:git_version).returns(version)
          lambda { Command.verify_minimum_git_version! }.should.not.raise
        end
      end

      invalid_git_versions.each do |version|
        it "raises an error for version #{version}" do
          Command.expects(:git_version).returns(version)
          lambda { Command.verify_minimum_git_version! }.should.raise Informative
        end
      end
    end

    describe 'ensure_not_root_or_allowed!' do
      it 'passes check with ENV["COCOAPODS_ALLOW_ROOT"]' do
        stored_env = ENV['COCOAPODS_ALLOW_ROOT']
        ENV['COCOAPODS_ALLOW_ROOT'] = '1'
        lambda { Command.ensure_not_root_or_allowed!([], 123, false) }.should.not.raise
        lambda { Command.ensure_not_root_or_allowed!([], 0, false) }.should.not.raise
        lambda { Command.ensure_not_root_or_allowed!([], 123, true) }.should.not.raise
        lambda { Command.ensure_not_root_or_allowed!([], 0, true) }.should.not.raise
        lambda { Command.ensure_not_root_or_allowed!(['--allow-root'], 123, false) }.should.not.raise
        lambda { Command.ensure_not_root_or_allowed!(['--allow-root'], 0, false) }.should.not.raise
        lambda { Command.ensure_not_root_or_allowed!(['--allow-root'], 123, true) }.should.not.raise
        lambda { Command.ensure_not_root_or_allowed!(['--allow-root'], 0, true) }.should.not.raise
        ENV['COCOAPODS_ALLOW_ROOT'] = stored_env
      end

      it 'prevents the gem from running as root without flag' do
        lambda { Command.ensure_not_root_or_allowed!([], 0, false) }.should.raise CLAide::Help
      end

      it 'skips root check on Widnows' do
        lambda { Command.ensure_not_root_or_allowed!([], 0, true) }.should.not.raise
        lambda { Command.ensure_not_root_or_allowed!([], 123, true) }.should.not.raise
        lambda { Command.ensure_not_root_or_allowed!(['--allow-root'], 0, true) }.should.not.raise
        lambda { Command.ensure_not_root_or_allowed!(['--allow-root'], 123, true) }.should.not.raise
      end

      it 'passes check when Process.uid != 0' do
        lambda { Command.ensure_not_root_or_allowed!([], 123, false) }.should.not.raise
        lambda { Command.ensure_not_root_or_allowed!([], 123, true) }.should.not.raise
        lambda { Command.ensure_not_root_or_allowed!(['--allow-root'], 123, true) }.should.not.raise
        lambda { Command.ensure_not_root_or_allowed!(['--allow-root'], 123, false) }.should.not.raise
      end

      it 'passes check with --allow-root flag' do
        lambda { Command.ensure_not_root_or_allowed!(['--allow-root'], 123, false) }.should.not.raise
        lambda { Command.ensure_not_root_or_allowed!(['--allow-root'], 0, false) }.should.not.raise
        lambda { Command.ensure_not_root_or_allowed!(['--allow-root'], 123, true) }.should.not.raise
        lambda { Command.ensure_not_root_or_allowed!(['--allow-root'], 0, true) }.should.not.raise
      end
    end

    describe 'git version extraction' do
      git_versions = [
        ['git version 1.2.4', Gem::Version.new('1.2.4')],
        ['git version 1.4.5', Gem::Version.new('1.4.5')],
        ['git version 1.7.4', Gem::Version.new('1.7.4')],
        ['git version 2.10.2', Gem::Version.new('2.10.2')],
        ['git version 2.10.2', Gem::Version.new('2.10.2')],
        ['git version 2.8.4 (Apple Git-73)', Gem::Version.new('2.8.4')],
      ]

      git_versions.each do |pair|
        it "returns the correct version for #{pair[0]}" do
          Executable.expects(:capture_command).with('git', ['--version']).returns([pair[0]])
          Command.git_version.should == pair[1]
        end
      end
    end
  end
end
