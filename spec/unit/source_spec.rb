require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Source" do
  extend SpecHelper::Git
  extend SpecHelper::TemporaryDirectory

  before do
    Pod::Source.reset!
    Pod::Spec::Set.reset!
    add_repo('repo1', fixture('spec-repos/master'))
    (config.repos_dir + 'repo1/JSONKit').rmtree
    add_repo('repo2', fixture('spec-repos/master'))
    (config.repos_dir + 'repo2/Reachability').rmtree
  end

  it "returns a specification set by name from any spec repo" do
    set = Pod::Source.search(Pod::Dependency.new('Reachability'))
    set.should == Pod::Spec::Set.by_pod_dir(config.repos_dir + 'repo1/Reachability')
    set = Pod::Source.search(Pod::Dependency.new('JSONKit'))
    set.should == Pod::Spec::Set.by_pod_dir(config.repos_dir + 'repo2/JSONKit')
  end

  it "returns a specification set by top level spec name" do
    set = Pod::Source.search(Pod::Dependency.new('JSONKit/SomeSubspec'))
    set.should == Pod::Spec::Set.by_pod_dir(config.repos_dir + 'repo2/JSONKit')
  end

  it "raises if a specification set can't be found" do
    lambda {
      Pod::Source.search(Pod::Dependency.new('DoesNotExist'))
    }.should.raise Pod::Informative
  end
end
