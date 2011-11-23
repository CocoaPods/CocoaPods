require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Dependency" do
  it "merges dependencies (taken from newer RubyGems version)" do
    dep1 = Pod::Dependency.new('bananas', '>= 1.8')
    dep2 = Pod::Dependency.new('bananas', '1.9')
    dep1.merge(dep2).should == Pod::Dependency.new('bananas', '>= 1.8', '1.9')
  end

  it "is equal to another dependency if `part_of_other_pod' is the same" do
    dep1 = Pod::Dependency.new('bananas', '>= 1')
    dep1.only_part_of_other_pod = true
    dep2 = Pod::Dependency.new('bananas', '>= 1')
    dep1.should.not == dep2
    dep2.only_part_of_other_pod = true
    dep1.should == dep2
  end

  it "returns the name of the dependency, or the name of the pod of which this is a subspec" do
    dep = Pod::Dependency.new('RestKit')
    dep.top_level_spec_name.should == 'RestKit'
    dep = Pod::Dependency.new('RestKit/Networking')
    dep.top_level_spec_name.should == 'RestKit'
  end

  it "is equal to another dependency if `external_spec_source' is the same" do
    dep1 = Pod::Dependency.new('bananas', :git => 'GIT-URL')
    dep2 = Pod::Dependency.new('bananas')
    dep1.should.not == dep2
    dep2.external_spec_source = { :git => 'GIT-URL' }
    dep1.should == dep2
  end

  it "is equal to another dependency if `specification' is equal" do
    dep1 = Pod::Dependency.new { |s| s.name = 'bananas'; s.version = '1' }
    dep2 = Pod::Dependency.new('bananas')
    dep1.should.not == dep2
    dep2 = Pod::Dependency.new { |s| s.name = 'bananas'; s.version = '1' }
    dep1.should == dep2
  end
end
