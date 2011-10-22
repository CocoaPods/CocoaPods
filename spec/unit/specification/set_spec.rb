require File.expand_path('../../../spec_helper', __FILE__)

class Pod::Spec::Set
  def reset!
    @required_by = []
  end
end

describe "Pod::Specification::Set" do
  it "returns nil in case a set hasn't been resolved yet" do
    Pod::Spec::Set.reset!
    Pod::Spec::Set.by_specification_name('CocoaLumberjack').should == nil
  end

  before do
    @set = Pod::Spec::Set.by_pod_dir(fixture('spec-repos/master/CocoaLumberjack'))
    @set.reset!
  end

  it "returns a cached set by name once it has been resolved once" do
    Pod::Spec::Set.by_specification_name('CocoaLumberjack').should.eql @set
  end

  it "always returns the same set instance for a pod dir" do
    Pod::Spec::Set.by_pod_dir(fixture('spec-repos/master/CocoaLumberjack')).should.eql @set
  end

  it "returns the name of the pod" do
    @set.name.should == 'CocoaLumberjack'
  end

  it "returns the versions available for this pod ordered from highest to lowest" do
    @set.versions.should == %w[1.2.1 1.2 1.1 1.0].map { |v| Pod::Version.new(v) }
  end

  it "checks if the dependency of the specification is compatible with existing requirements" do
    @set.required_by(Pod::Spec.new { |s| s.dependency 'CocoaLumberjack', '1.2' })
    @set.required_by(Pod::Spec.new { |s| s.dependency 'CocoaLumberjack', '< 1.2.1' })
    @set.required_by(Pod::Spec.new { |s| s.dependency 'CocoaLumberjack', '> 1.1' })
    @set.required_by(Pod::Spec.new { |s| s.dependency 'CocoaLumberjack', '~> 1.2.0' })
    @set.required_by(Pod::Spec.new { |s| s.dependency 'CocoaLumberjack' })
    lambda {
      @set.required_by(Pod::Spec.new { |s| s.dependency 'CocoaLumberjack', '< 1.0' })
    }.should.raise Pod::Informative
  end

  it "raises if the required version doesn't exist" do
    @set.required_by(Pod::Spec.new { |s| s.dependency 'CocoaLumberjack', '< 1.0' })
    lambda { @set.required_version }.should.raise Pod::Informative
  end

  before do
    @set.required_by(Pod::Spec.new { |s| s.dependency 'CocoaLumberjack', '< 1.2.1' })
  end

  it "returns the version required for the dependency" do
    @set.required_version.should == Pod::Version.new('1.2')
  end

  it "returns the path to the specification for the required version" do
    @set.specification_path.should == fixture('spec-repos/master/CocoaLumberjack/1.2/CocoaLumberjack.podspec')
  end

  it "returns the specification for the required version" do
    @set.specification.should == Pod::Spec.new { |s| s.name = 'CocoaLumberjack'; s.version = '1.2' }
  end

  it "returns that this set is not only part for other pods" do
    @set.required_by(Pod::Spec.new { |s| s.part_of = 'CocoaLumberjack' })
    @set.should.not.be.only_part_of_other_pod
  end

  it "returns that this set is only part for other pods" do
    @set.reset!
    @set.required_by(Pod::Spec.new { |s| s.part_of = 'CocoaLumberjack' })
    @set.required_by(Pod::Spec.new { |s| s.part_of = 'CocoaLumberjack' })
    @set.should.be.only_part_of_other_pod
  end

  it "ignores dotfiles when getting the version directories" do
    `touch #{fixture('spec-repos/master/CocoaLumberjack/.DS_Store')}`
    lambda { @set.versions }.should.not.raise
  end
end
