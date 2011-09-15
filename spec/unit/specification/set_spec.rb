require File.expand_path('../../../spec_helper', __FILE__)

class Pod::Spec::Set
  def reset!
    @required_by = []
  end
end

describe "Pod::Specification::Set" do
  it "returns nil in case a set hasn't been resolved yet" do
    Pod::Spec::Set.by_specification_name('ASIHTTPRequest').should == nil
  end

  before do
    @set = Pod::Spec::Set.by_pod_dir(fixture('spec-repos/master/ASIHTTPRequest'))
    @set.reset!
  end

  it "returns a cached set by name once it has been resolved once" do
    Pod::Spec::Set.by_specification_name('ASIHTTPRequest').should.eql @set
  end

  it "always returns the same set instance for a pod dir" do
    Pod::Spec::Set.by_pod_dir(fixture('spec-repos/master/ASIHTTPRequest')).should.eql @set
  end

  it "returns the name of the pod" do
    @set.name.should == 'ASIHTTPRequest'
  end

  it "returns the versions available for this pod ordered from highest to lowest" do
    @set.versions.should == [Pod::Version.new('1.8.1'), Pod::Version.new('1.8')]
  end

  it "checks if the dependency of the specification is compatible with existing requirements" do
    @set.required_by(Pod::Spec.new { dependency 'ASIHTTPRequest', '1.8' })
    @set.required_by(Pod::Spec.new { dependency 'ASIHTTPRequest', '< 1.8.1' })
    @set.required_by(Pod::Spec.new { dependency 'ASIHTTPRequest', '> 1.7.9' })
    @set.required_by(Pod::Spec.new { dependency 'ASIHTTPRequest', '~> 1.8.0' })
    @set.required_by(Pod::Spec.new { dependency 'ASIHTTPRequest' })
    lambda { @set.required_by(Pod::Spec.new { dependency 'ASIHTTPRequest', '< 1.8' }) }.should.raise
  end

  it "raises if the required version doesn't exist" do
    @set.required_by(Pod::Spec.new { dependency 'ASIHTTPRequest', '< 1.8' })
    lambda { @set.required_version }.should.raise
  end

  before do
    @set.required_by(Pod::Spec.new { dependency 'ASIHTTPRequest', '< 1.8.1' })
  end

  it "returns the version required for the dependency" do
    @set.required_version.should == Pod::Version.new('1.8')
  end

  it "returns the path to the specification for the required version" do
    @set.specification_path.should == fixture('spec-repos/master/ASIHTTPRequest/1.8/ASIHTTPRequest.podspec')
  end

  it "returns the specification for the required version" do
    @set.specification.should == Pod::Spec.new { name 'ASIHTTPRequest'; version '1.8' }
  end

  it "returns that this set is not only part for other pods" do
    @set.required_by(Pod::Spec.new { part_of 'ASIHTTPRequest' })
    @set.should.not.be.only_part_of_other_pod
  end

  it "returns that this set is only part for other pods" do
    @set.reset!
    @set.required_by(Pod::Spec.new { part_of 'ASIHTTPRequest' })
    @set.required_by(Pod::Spec.new { part_of 'ASIHTTPRequest' })
    @set.should.be.only_part_of_other_pod
  end
end
