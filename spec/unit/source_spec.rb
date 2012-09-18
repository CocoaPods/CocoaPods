require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Source" do
  extend SpecHelper::Command
  extend SpecHelper::TemporaryDirectory
  extend SpecHelper::TemporaryRepos

  before do
    add_repo('repo1', fixture('spec-repos/master'))
    (config.repos_dir + 'repo1/JSONKit').rmtree
    add_repo('repo2', fixture('spec-repos/master'))
    (config.repos_dir + 'repo2/Reachability').rmtree
  end

  it "returns a specification set by name from any spec repo" do
    set = Pod::Source.search(Pod::Dependency.new('Reachability'))
    set.should == Pod::Spec::Set.new(config.repos_dir + 'repo1/Reachability')
    set = Pod::Source.search(Pod::Dependency.new('JSONKit'))
    set.should == Pod::Spec::Set.new(config.repos_dir + 'repo2/JSONKit')
  end

  it "returns a specification set by top level spec name" do
    (config.repos_dir + 'repo2/RestKit').rmtree
    set = Pod::Source.search(Pod::Dependency.new('RestKit/Network'))
    set.should == Pod::Spec::Set.new(config.repos_dir + 'repo1/RestKit')
  end

  it "raises if a specification set can't be found" do
    lambda {
      Pod::Source.search(Pod::Dependency.new('DoesNotExist'))
    }.should.raise Pod::Informative
  end

  it "raises if a subspec can't be found" do
    lambda {
      Pod::Source.search(Pod::Dependency.new('RestKit/DoesNotExist'))
    }.should.raise Pod::Informative
  end

  it "return the names of the repos" do
    Pod::Source.names.should == %w| repo1 repo2 |
  end
end
