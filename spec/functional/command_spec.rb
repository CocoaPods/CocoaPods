require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Command" do
  extend SpecHelper::Git
  extend SpecHelper::TemporaryDirectory

  before do
    fixture('spec-repos/master') # ensure the archive is unpacked
  end

  it "creates the local spec-repos directory and creates a clone of the `master' repo" do
    command = Pod::Command.parse('setup')
    def command.master_repo_url; SpecHelper.fixture('spec-repos/master'); end
    command.run
    git_config('master', 'remote.origin.url').should == fixture('spec-repos/master').to_s
  end

  it "adds a spec-repo" do
    add_repo('private', fixture('spec-repos/master'))
    git_config('private', 'remote.origin.url').should == fixture('spec-repos/master').to_s
  end

  it "updates a spec-repo" do
    repo1 = add_repo('repo1', fixture('spec-repos/master'))
    repo2 = add_repo('repo2', repo1.dir)
    make_change(repo1, 'repo1')
    command('repo', 'update', 'repo2')
    (repo2.dir + 'README').read.should.include 'Added!'
  end

  it "updates all the spec-repos" do
    repo1 = add_repo('repo1', fixture('spec-repos/master'))
    repo2 = add_repo('repo2', repo1.dir)
    repo3 = add_repo('repo3', repo1.dir)
    make_change(repo1, 'repo1')
    command('repo', 'update')
    (repo2.dir + 'README').read.should.include 'Added!'
    (repo3.dir + 'README').read.should.include 'Added!'
  end
end
