require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Dependency" do
  it "merges dependencies (taken from newer RubyGems version)" do
    dep1 = Pod::Dependency.new('bananas', '>= 1.8')
    dep2 = Pod::Dependency.new('bananas', '1.9')
    dep1.merge(dep2).should == Pod::Dependency.new('bananas', '>= 1.8', '1.9')
  end

  it "is equal to another dependency if the `part_of_other_pod' flag is the same" do
    dep1 = Pod::Dependency.new('bananas', '>= 1')
    dep1.only_part_of_other_pod = true
    dep2 = Pod::Dependency.new('bananas', '>= 1')
    dep1.should.not == dep2
    dep2.only_part_of_other_pod = true
    dep1.should == dep2
  end
end
