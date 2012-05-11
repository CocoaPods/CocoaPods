require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Resolver" do
  before do
    @config_before = config
    Pod::Config.instance = nil
    config.silent = true
    config.repos_dir = fixture('spec-repos')
    @podfile = Pod::Podfile.new do
      platform :ios
      dependency 'ASIWebPageRequest'
    end
    @resolver = Pod::Resolver.new(@podfile, stub('sandbox'))
  end

  after do
    Pod::Config.instance = @config_before
  end

  it "holds the context state, such as cached specification sets" do
    @resolver.resolve
    @resolver.cached_sets.values.sort_by(&:name).should == [
      Pod::Spec::Set.new(config.repos_dir + 'master/ASIHTTPRequest'),
      Pod::Spec::Set.new(config.repos_dir + 'master/ASIWebPageRequest'),
      Pod::Spec::Set.new(config.repos_dir + 'master/Reachability'),
    ].sort_by(&:name)
  end

  it "returns all specs needed for the dependency" do
    specs = @resolver.resolve.values.flatten
    specs.map(&:class).uniq.should == [Pod::Specification]
    specs.map(&:name).sort.should == %w{ ASIHTTPRequest ASIWebPageRequest Reachability }
  end

  it "does not raise if all dependencies match the platform of the root spec (Podfile)" do
    @podfile.platform :ios
    lambda { @resolver.resolve }.should.not.raise
    @podfile.platform :osx
    lambda { @resolver.resolve }.should.not.raise
  end

  it "raises once any of the dependencies does not match the platform of its podfile target" do
    set = Pod::Spec::Set.new(config.repos_dir + 'master/ASIHTTPRequest')
    @resolver.cached_sets['ASIHTTPRequest'] = set

    def set.stub_platform=(platform); @stubbed_platform = platform; end
    def set.specification; spec = super; spec.platform = @stubbed_platform; spec; end

    @podfile.platform :ios
    set.stub_platform = :ios
    lambda { @resolver.resolve }.should.not.raise
    set.stub_platform = :osx
    lambda { @resolver.resolve }.should.raise Pod::Informative

    @podfile.platform :osx
    set.stub_platform = :osx
    lambda { @resolver.resolve }.should.not.raise
    set.stub_platform = :ios
    lambda { @resolver.resolve }.should.raise Pod::Informative
  end

  it "raises once any of the dependencies does not have a deployment_target compatible with its podfile target" do
    set = Pod::Spec::Set.new(config.repos_dir + 'master/ASIHTTPRequest')
    @resolver.cached_sets['ASIHTTPRequest'] = set
    @podfile.platform :ios, "4.0"

    Pod::Specification.any_instance.stubs(:platforms).returns([ Pod::Platform.new(:ios, '4.0'), Pod::Platform.new(:osx, '10.7') ])
    lambda { @resolver.resolve }.should.not.raise

    Pod::Specification.any_instance.stubs(:platforms).returns([ Pod::Platform.new(:ios, '5.0'), Pod::Platform.new(:osx, '10.7') ])
    lambda { @resolver.resolve }.should.raise Pod::Informative
  end

  it "resolves subspecs" do
    @podfile = Pod::Podfile.new do
      platform :ios
      dependency 'RestKit/Network'
      dependency 'RestKit/ObjectMapping'
    end
    resolver = Pod::Resolver.new(@podfile, stub('sandbox'))
    resolver.resolve.values.flatten.map(&:name).sort.should == %w{
      FileMD5Hash
      ISO8601DateFormatter
      LibComponentLogging-Core
      LibComponentLogging-NSLog
      RestKit
      RestKit/Network
      RestKit/ObjectMapping
      SOCKit
      cocoa-oauth
    }
  end
  
  it "resolves subspecs with external constraints" do
    @podfile = Pod::Podfile.new do
      platform :ios
      dependency 'MainSpec/FirstSubSpec', :git => 'GIT-URL'
    end
    spec = Pod::Spec.new do |s|
      s.name    = 'MainSpec'
      s.version = '1.2.3'
      s.platform = :ios
      s.license = 'MIT'
      s.author = 'Joe the Plumber'
      s.summary = 'A spec with subspecs'
      s.source  = { :git => '/some/url' }
      s.requires_arc = true

      s.subspec 'FirstSubSpec' do |fss|
        fss.source_files = 'some/file'

        fss.subspec 'SecondSubSpec' do |sss|
        end
      end
    end
    @podfile.dependencies.first.external_source.stubs(:specification_from_sandbox).returns(spec)
    resolver = Pod::Resolver.new(@podfile, stub('sandbox'))
    resolver.resolve.values.flatten.map(&:name).sort.should == %w{
      MainSpec
      MainSpec/FirstSubSpec
    }
  end
end

