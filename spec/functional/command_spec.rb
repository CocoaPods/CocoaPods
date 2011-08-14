require File.expand_path('../../spec_helper', __FILE__)
require 'executioner'

describe "Pod::Command" do
  extend SpecHelper::Fixture
  extend SpecHelper::Git
  extend SpecHelper::Log
  extend SpecHelper::TemporaryDirectory

  it "creates the local spec-repos directory and creates a clone of the `master' repo" do
    #log!

    command = Pod::Command.parse("setup")
    def command.repos_dir; SpecHelper.tmp_repos_path; end
    def command.master_repo_url; SpecHelper.fixture('master-spec-repo.git'); end

    command.run
    File.should.exist command.master_repo_dir
    git_config('remote.origin.url').should == command.master_repo_url
  end
end
