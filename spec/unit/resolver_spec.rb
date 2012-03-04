require File.expand_path('../../spec_helper', __FILE__)

class StubbedSet < Pod::Specification::Set
  attr_accessor :stub_platform

  def specification
    spec = super
    spec.platform = @stub_platform
    spec
  end
end

class StubbedResolver < Pod::Resolver
  attr_accessor :stub_platform

  def find_dependency_set(dependency)
    set = StubbedSet.new(super.pod_dir)
    set.stub_platform = @stub_platform
    set
  end
end

describe "Pod::Resolver" do
  before do
    Pod::Spec::Set.reset!
    @config_before = config
    Pod::Config.instance = nil
    config.silent = true
    config.repos_dir = fixture('spec-repos')
    @podfile = Pod::Podfile.new do
      platform :ios
      dependency 'ASIWebPageRequest'
    end
    config.rootspec = @podfile
  end

  after do
    Pod::Config.instance = @config_before
  end

  it "returns all specs needed for the dependency" do
    specs = Pod::Resolver.new(@podfile, stub('sandbox')).resolve.values.flatten
    specs.map(&:class).uniq.should == [Pod::Specification]
    specs.map(&:name).sort.should == %w{ ASIHTTPRequest ASIWebPageRequest Reachability }
  end

  it "does not raise if all dependencies match the platform of the root spec (Podfile)" do
    resolver = Pod::Resolver.new(@podfile, stub('sandbox'))

    @podfile.platform :ios
    lambda { resolver.resolve }.should.not.raise
    @podfile.platform :osx
    lambda { resolver.resolve }.should.not.raise
  end

  it "raises once any of the dependencies does not match the platform of the root spec (Podfile)" do
    resolver = StubbedResolver.new(config.rootspec, stub('sandbox'))

    @podfile.platform :ios
    resolver.stub_platform = :ios
    lambda { resolver.resolve }.should.not.raise
    resolver.stub_platform = :osx
    lambda { resolver.resolve }.should.raise Pod::Informative

    @podfile.platform :osx
    resolver.stub_platform = :osx
    lambda { resolver.resolve }.should.not.raise
    resolver.stub_platform = :ios
    lambda { resolver.resolve }.should.raise Pod::Informative
  end

  it "resolves subspecs" do
    @podfile = Pod::Podfile.new do
      platform :ios
      dependency 'RestKit/Network'
      dependency 'RestKit/ObjectMapping'
    end
    config.rootspec = @podfile
    resolver = Pod::Resolver.new(@podfile, stub('sandbox'))
    resolver.resolve.values.flatten.map(&:name).sort.should == %w{ LibComponentLogging-Core LibComponentLogging-NSLog RestKit RestKit/Network RestKit/ObjectMapping }
  end
end

