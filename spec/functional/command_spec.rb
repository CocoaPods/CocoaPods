require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Command" do
  extend SpecHelper::Git
  extend SpecHelper::Log
  extend SpecHelper::TemporaryDirectory

  before do
    fixture('master-spec-repo.git') # ensure the archive is unpacked
  end

  it "creates the local spec-repos directory and creates a clone of the `master' repo" do
    command = Pod::Command.parse('setup')
    def command.master_repo_url; SpecHelper.fixture('master-spec-repo.git'); end
    command.run
    git_config('master', 'remote.origin.url').should == fixture('master-spec-repo.git').to_s
  end

  def command(*argv)
    command = Pod::Command.parse(*argv)
    command.run
    command
  end

  it "adds a spec-repo" do
    command('repo', 'add', 'private', fixture('master-spec-repo.git'))
    git_config('private', 'remote.origin.url').should == fixture('master-spec-repo.git').to_s
  end

  it "updates a spec-repo" do
    repo1 = command('repo', 'add', 'repo1', fixture('master-spec-repo.git'))
    repo2 = command('repo', 'add', 'repo2', repo1.dir)

    (repo1.dir + 'README').open('a') { |f| f << 'updated!' }
    git('repo1', 'commit -a -m "update"')

    command('repo', 'update', 'repo2')
    (repo2.dir + 'README').read.should.include 'updated!'
  end

  it "updates all the spec-repos" do
    repo1 = command('repo', 'add', 'repo1', fixture('master-spec-repo.git'))
    repo2 = command('repo', 'add', 'repo2', repo1.dir)
    repo3 = command('repo', 'add', 'repo3', repo1.dir)

    (repo1.dir + 'README').open('a') { |f| f << 'updated!' }
    git('repo1', 'commit -a -m "update"')

    command('repo', 'update')
    (repo2.dir + 'README').read.should.include 'updated!'
    (repo3.dir + 'README').read.should.include 'updated!'
  end
end
