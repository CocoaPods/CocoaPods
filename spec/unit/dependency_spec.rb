require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Dependency" do
  it "merges dependencies (taken from newer RubyGems version)" do
    dep1 = Pod::Dependency.new('bananas', '>= 1.8')
    dep2 = Pod::Dependency.new('bananas', '1.9')
    dep1.merge(dep2).should == Pod::Dependency.new('bananas', '>= 1.8', '1.9')
  end
end
