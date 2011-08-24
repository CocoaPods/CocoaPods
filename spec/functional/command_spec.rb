require File.expand_path('../../spec_helper', __FILE__)
require 'executioner'

describe "Pod::Command" do
  extend SpecHelper::Fixture
  extend SpecHelper::Git
  extend SpecHelper::Log
  extend SpecHelper::TemporaryDirectory

  it "creates the local spec-repos directory and creates a clone of the `master' repo" do
    command = Pod::Command.parse('setup')
    def command.master_repo_url; SpecHelper.fixture('master-spec-repo.git'); end
    def (command.add_master_repo_command).repos_dir; SpecHelper.tmp_repos_path; end

    command.run
    git_config('master', 'remote.origin.url').should == fixture('master-spec-repo.git')
  end

  def command(*argv)
    command = Pod::Command.parse(*argv)
    def command.repos_dir; SpecHelper.tmp_repos_path; end
    command.run
    command
  end

  it "adds a spec-repo" do
    command('repo', 'add', 'private', fixture('master-spec-repo.git'))
    git_config('private', 'remote.origin.url').should == fixture('master-spec-repo.git')
  end

  it "updates a spec-repo" do
    repo1 = command('repo', 'add', 'repo1', fixture('master-spec-repo.git'))
    repo2 = command('repo', 'add', 'repo2', repo1.dir)

    File.open(File.join(repo1.dir, 'README'), 'a') { |f| f << 'updated!' }
    git('repo1', 'commit -a -m "update"')

    command('repo', 'update', 'repo2')
    File.read(File.join(repo2.dir, 'README')).should.include 'updated!'
  end

  it "updates all the spec-repos" do
    repo1 = command('repo', 'add', 'repo1', fixture('master-spec-repo.git'))
    repo2 = command('repo', 'add', 'repo2', repo1.dir)
    repo3 = command('repo', 'add', 'repo3', repo1.dir)

    File.open(File.join(repo1.dir, 'README'), 'a') { |f| f << 'updated!' }
    git('repo1', 'commit -a -m "update"')

    command('repo', 'update')
    File.read(File.join(repo2.dir, 'README')).should.include 'updated!'
    File.read(File.join(repo3.dir, 'README')).should.include 'updated!'
  end
end
