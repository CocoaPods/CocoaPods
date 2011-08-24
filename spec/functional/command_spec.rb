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

  it "adds a spec-repo" do
    command = Pod::Command.parse('repo', 'add', 'private', fixture('master-spec-repo.git'))
    def command.repos_dir; SpecHelper.tmp_repos_path; end

    command.run
    git_config('private', 'remote.origin.url').should == fixture('master-spec-repo.git')
  end

  it "updates a spec-repo" do
    repo1 = Pod::Command.parse('repo', 'add', 'repo1', fixture('master-spec-repo.git'))
    def repo1.repos_dir; SpecHelper.tmp_repos_path; end
    repo1.run

    repo2 = Pod::Command.parse('repo', 'add', 'repo2', repo1.dir)
    def repo2.repos_dir; SpecHelper.tmp_repos_path; end
    repo2.run

    File.open(File.join(repo1.dir, 'README'), 'a') { |f| f << 'updated!' }
    git('repo1', 'commit -a -m "update"')

    command = Pod::Command.parse('repo', 'update', 'repo2')
    def command.repos_dir; SpecHelper.tmp_repos_path; end
    command.run

    File.read(File.join(repo2.dir, 'README')).should.include 'updated!'
  end
end
