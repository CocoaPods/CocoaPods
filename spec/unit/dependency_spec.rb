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

  it "returns a copy of the dependency but for the top level spec, if it's a subspec" do
    dep = Pod::Dependency.new('RestKit', '>= 1.2.3')
    dep.to_top_level_spec_dependency.should == Pod::Dependency.new('RestKit', '>= 1.2.3')
    dep = Pod::Dependency.new('RestKit/Networking', '>= 1.2.3')
    dep.to_top_level_spec_dependency.should == Pod::Dependency.new('RestKit', '>= 1.2.3')
  end

  it "is equal to another dependency if `external_source' is the same" do
    dep1 = Pod::Dependency.new('bananas', :git => 'GIT-URL')
    dep2 = Pod::Dependency.new('bananas')
    dep1.should.not == dep2
    dep3 = Pod::Dependency.new('bananas', :git => 'GIT-URL')
    dep1.should == dep3
  end

  it "is equal to another dependency if `specification' is equal" do
    dep1 = Pod::Dependency.new { |s| s.name = 'bananas'; s.version = '1' }
    dep2 = Pod::Dependency.new('bananas')
    dep1.should.not == dep2
    dep2 = Pod::Dependency.new { |s| s.name = 'bananas'; s.version = '1' }
    dep1.should == dep2
  end
  
  it 'raises if created without either valid name/version/external requirements or a block' do
    lambda { Pod::Dependency.new }.should.raise Pod::Informative
  end
end

describe "Pod::Dependency", "defined with a block" do
  before do
    @dependency = Pod::Dependency.new do |spec|
      spec.name    = "my-custom-spec"
      spec.version = "1.0.3"
    end
  end
  
  it 'it identifies itself as an inline dependency' do
    @dependency.should.be.inline
  end
  
  it 'attaches a custom spec to the dependency, configured by the block' do
    @dependency.specification.name.should == "my-custom-spec"
  end
end

describe "Pod::Dependency", "with a hash of external source settings" do
  before do
    @dependency = Pod::Dependency.new("cocoapods", :git => "git://github.com/cocoapods/cocoapods")
  end
  
  it 'it identifies itself as an external dependency' do
    @dependency.should.be.external
  end
end
