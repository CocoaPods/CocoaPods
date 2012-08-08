require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Resolver do
    before do
      config.repos_dir = fixture('spec-repos')

      @podfile = Podfile.new do
        platform :ios
        pod 'BlocksKit'
        # pod 'ASIWebPageRequest'
      end
      @resolver = Resolver.new(@podfile, nil, stub('sandbox'))
    end

    it "holds the context state, such as cached specification sets" do
      @resolver.resolve
      @resolver.cached_sets.values.sort_by(&:name).should == [
        Spec::Set.new(config.repos_dir + 'master/A2DynamicDelegate'),
        Spec::Set.new(config.repos_dir + 'master/BlocksKit'),
        Spec::Set.new(config.repos_dir + 'master/libffi'),
      ].sort_by(&:name)
    end

    it "returns all specs needed for the dependency" do
      specs = @resolver.resolve.values.flatten
      specs.map(&:class).uniq.should == [Specification]
      specs.map(&:name).sort.should == %w{ A2DynamicDelegate BlocksKit libffi }
    end

    it "does not raise if all dependencies match the platform of the root spec (Podfile)" do
      @podfile.platform :ios
      lambda { @resolver.resolve }.should.not.raise
      @podfile.platform :osx
      lambda { @resolver.resolve }.should.not.raise
    end

    it "raises once any of the dependencies does not match the platform of its podfile target" do
      set = Spec::Set.new(config.repos_dir + 'master/BlocksKit')
      @resolver.cached_sets['BlocksKit'] = set

      def set.stub_platform=(platform); @stubbed_platform = platform; end
      def set.specification; spec = super; spec.platform = @stubbed_platform; spec; end

      @podfile.platform :ios
      set.stub_platform = :ios
      lambda { @resolver.resolve }.should.not.raise
      set.stub_platform = :osx
      lambda { @resolver.resolve }.should.raise Informative

      @podfile.platform :osx
      set.stub_platform = :osx
      lambda { @resolver.resolve }.should.not.raise
      set.stub_platform = :ios
      lambda { @resolver.resolve }.should.raise Informative
    end

    it "raises once any of the dependencies does not have a deployment_target compatible with its podfile target" do
      set = Spec::Set.new(config.repos_dir + 'master/BlocksKit')
      @resolver.cached_sets['BlocksKit'] = set
      @podfile.platform :ios, "4.0"

      Specification.any_instance.stubs(:available_platforms).returns([ Platform.new(:ios, '4.0'), Platform.new(:osx, '10.7') ])
      lambda { @resolver.resolve }.should.not.raise

      Specification.any_instance.stubs(:available_platforms).returns([ Platform.new(:ios, '5.0'), Platform.new(:osx, '10.7') ])
      lambda { @resolver.resolve }.should.raise Informative
    end

    it "resolves subspecs" do
      @podfile = Podfile.new do
        platform :ios
        pod 'RestKit/Network'
        pod 'RestKit/ObjectMapping/XML'
      end
      resolver = Resolver.new(@podfile, nil, stub('sandbox'))
      resolver.resolve.values.flatten.map(&:name).sort.should == %w{
        FileMD5Hash
        ISO8601DateFormatter
        LibComponentLogging-Core
        LibComponentLogging-NSLog
        NSData+Base64
        RestKit/Network
        RestKit/ObjectMapping/XML
        SOCKit
        XMLReader
        cocoa-oauth
      }
    end

    it "includes all the subspecs of a specification node" do
      @podfile = Podfile.new do
        platform :ios
        pod 'RestKit'
      end
      resolver = Resolver.new(@podfile, nil, stub('sandbox'))
      resolver.resolve.values.flatten.map(&:name).sort.should == %w{
        FileMD5Hash
        ISO8601DateFormatter
        JSONKit
        LibComponentLogging-Core
        LibComponentLogging-NSLog
        NSData+Base64
        RestKit
        RestKit/JSON
        RestKit/Network
        RestKit/ObjectMapping/CoreData
        RestKit/ObjectMapping/JSON
        RestKit/UI
        SOCKit
        cocoa-oauth
      }
    end

    it "it includes only the main subspec of a specification node" do
      @podfile = Podfile.new do
        platform :ios
        pod do |s|
          s.name         = 'RestKit'
          s.version      = '0.10.0'

          s.preferred_dependency = 'JSON'

          s.subspec 'JSON' do |js|
            js.dependency 'RestKit/Network'
            js.dependency 'RestKit/UI'
            js.dependency 'RestKit/ObjectMapping/JSON'
            js.dependency 'RestKit/ObjectMapping/CoreData'
          end

          s.subspec 'Network' do |ns|
            ns.dependency 'LibComponentLogging-NSLog', '>= 1.0.4'
          end
          s.subspec 'UI'
          s.subspec 'ObjectMapping' do |os|
            os.subspec 'JSON'
            os.subspec 'XML'
            os.subspec 'CoreData'
          end
        end
      end
      resolver = Resolver.new(@podfile, nil, stub('sandbox'))
      specs = resolver.resolve.values.flatten.map(&:name).sort
      specs.should.not.include 'RestKit/ObjectMapping/XML'
      specs.should == %w{
        LibComponentLogging-Core
        LibComponentLogging-NSLog
        RestKit
        RestKit/JSON
        RestKit/Network
        RestKit/ObjectMapping/CoreData
        RestKit/ObjectMapping/JSON
        RestKit/UI
      }
    end

    it "resolves subspecs with external constraints" do
      @podfile = Podfile.new do
        platform :ios
        pod 'MainSpec/FirstSubSpec', :git => 'GIT-URL'
      end
      spec = Spec.new do |s|
        s.name         = 'MainSpec'
        s.version      = '1.2.3'
        s.platform     = :ios
        s.license      = 'MIT'
        s.author       = 'Joe the Plumber'
        s.summary      = 'A spec with subspecs'
        s.source       = { :git => '/some/url' }
        s.requires_arc = true

        s.subspec 'FirstSubSpec' do |fss|
          fss.source_files = 'some/file'
          fss.subspec 'SecondSubSpec'
        end
      end
      @podfile.dependencies.first.external_source.stubs(:specification_from_sandbox).returns(spec)
      resolver = Resolver.new(@podfile, nil, stub('sandbox'))
      resolver.resolve.values.flatten.map(&:name).sort.should == %w{ MainSpec/FirstSubSpec MainSpec/FirstSubSpec/SecondSubSpec }
    end

    it "marks a specification's version to be a `bleeding edge' version" do
      podfile = Podfile.new do
        platform :ios
        pod 'FileMD5Hash'
        pod 'JSONKit', :head
      end
      resolver = Resolver.new(podfile, nil, stub('sandbox'))
      filemd5hash, jsonkit = resolver.resolve.values.first.sort_by(&:name)
      filemd5hash.version.should.not.be.head
      jsonkit.version.should.be.head
    end

    xit "raises if it finds two conflicting dependencies" do

    end

    describe "Concerning the Lockfile" do
      xit "accepts a nil lockfile" do
        lambda { Resolver.new(@podfile, nil, stub('sandbox'))}.should.not.raise
      end

      xit "detects the pods that need to be installed" do

      end

      xit "detects the pods that don't need to be installed" do

      end

      xit "detects the pods that can be updated" do

      end

      xit "doesn't install new pods in `update_mode'" do

      end

      xit "handles correctly pods with external source" do

      end

      xit "it always suggest to update pods in head mode" do

      end

      xit "it prevents a pod from upgrading during an install" do

      end
    end
  end
end
