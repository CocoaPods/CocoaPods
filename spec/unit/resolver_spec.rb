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

    it "accepts a nil lockfile" do
      lambda { Resolver.new(@podfile, nil, stub('sandbox'))}.should.not.raise
    end

    it "raises if it finds two conflicting dependencies" do
      podfile = Podfile.new do
        platform :ios
        pod 'JSONKit', "1.4"
        pod 'JSONKit', "1.5pre"
      end
      resolver = Resolver.new(podfile, nil, stub('sandbox'))
      lambda {resolver.resolve}.should.raise Pod::Informative
    end

    describe "Concerning Installation mode" do
      before do
        config.repos_dir = fixture('spec-repos')
        @podfile = Podfile.new do
          platform :ios
          pod 'BlocksKit'
          pod 'JSONKit'
        end
        @specs = [
          Pod::Specification.new do |s|
            s.name = "BlocksKit"
            s.version = "1.0.0"
          end,
          Pod::Specification.new do |s|
            s.name = "JSONKit"
            s.version = "1.4"
          end ]
        @specs.each { |s| s.activate_platform(:ios) }
        @lockfile = Lockfile.generate(@podfile, @specs)
        @resolver = Resolver.new(@podfile, @lockfile, stub('sandbox'))
      end

      it "doesn't install pods still compatible with the Podfile" do
        @resolver.resolve
        @resolver.should_install?("BlocksKit").should.be.false
        @resolver.should_install?("JSONKit").should.be.false
      end

      it "doesn't update the version of pods still compatible with the Podfile" do
        installed = @resolver.resolve.values.flatten.map(&:to_s)
        installed.should.include? "JSONKit (1.4)"
      end

      it "doesn't include pods removed from the Podfile" do
        podfile = Podfile.new { platform :ios; pod 'JSONKit' }
        @resolver = Resolver.new(podfile, @lockfile, stub('sandbox'))
        @resolver.resolve.values.flatten.map(&:name).should == %w{ JSONKit }
      end

      it "reinstalls pods updated in the Podfile" do
        podfile = Podfile.new do
          platform :ios
          pod 'JSONKit', '1.5pre'
          pod 'BlocksKit'
        end
        @resolver = Resolver.new(podfile, @lockfile, stub('sandbox'))
        installed = @resolver.resolve.values.flatten.map(&:to_s)
        installed.should.include? "BlocksKit (1.0.0)"
        installed.should.include? "JSONKit (1.5pre)"
      end

      it "installs pods added to the Podfile" do
        podfile = Podfile.new do
          platform :ios
          pod 'JSONKit'
          pod 'BlocksKit'
          pod 'libPusher'
        end
        @resolver = Resolver.new(podfile, @lockfile, stub('sandbox'))
        installed = @resolver.resolve.values.flatten.map(&:to_s)
        installed.should.include? "libPusher (1.3)"
      end

      it "handles head pods" do
        podfile = Podfile.new do
          platform :ios
          pod 'JSONKit', :head   # Existing pod switched to head mode
          pod 'libPusher', :head # New pod
        end
        @resolver = Resolver.new(podfile, @lockfile, stub('sandbox'))
        @resolver.resolve
        @resolver.should_install?("JSONKit").should.be.true
        @resolver.should_install?("libPusher").should.be.true
      end

      it "handles pods from external dependencies" do
        podfile = Podfile.new do
          platform :ios
          pod 'libPusher', :git => 'GIT-URL'
        end
        spec = Spec.new do |s|
          s.name         = 'libPusher'
          s.version      = '1.3'
        end
        podfile.dependencies.first.external_source.stubs(:specification_from_sandbox).returns(spec)
        @resolver = Resolver.new(podfile, @lockfile, stub('sandbox'))
        @resolver.resolve
        @resolver.should_install?("JSONKit").should.be.false
      end
    end

    describe "Concerning Update mode" do
      before do
        config.repos_dir = fixture('spec-repos')
        @podfile = Podfile.new do
          platform :ios
          pod 'BlocksKit'
          pod 'JSONKit'
          pod 'libPusher'
        end
        @specs = [
          Pod::Specification.new do |s|
            s.name = "libPusher"
            s.version = "1.3"
          end,
          Pod::Specification.new do |s|
            s.name = "JSONKit"
            s.version = "1.4"
          end ]
        @specs.each { |s| s.activate_platform(:ios) }
        @lockfile = Lockfile.generate(@podfile, @specs)
        @resolver = Resolver.new(@podfile, @lockfile, stub('sandbox'))
        @resolver.update_mode = true
      end

      it "identifies the pods that can be updated" do
        installed = @resolver.resolve.values.flatten.map(&:to_s)
        installed.should.include? "JSONKit (1.5pre)"
        @resolver.should_install?("JSONKit").should.be.true
      end

      it "respects the constraints of the pofile" do
        podfile = Podfile.new do
          platform :ios
          pod 'BlocksKit'
          pod 'JSONKit', '1.4'
        end
        @resolver = Resolver.new(podfile, @lockfile, stub('sandbox'))
        @resolver.update_mode = true
        installed = @resolver.resolve.values.flatten.map(&:to_s)
        installed.should.include? "JSONKit (1.4)"
        @resolver.should_install?("JSONKit").should.be.false
      end

      it "installs new pods" do
        installed = @resolver.resolve.values.flatten.map(&:to_s)
        installed.join(' ').should.include?('BlocksKit')
        @resolver.should_install?("BlocksKit").should.be.true
      end

      it "it always suggests to update pods in head mode" do
        podfile = Podfile.new do
          platform :ios
          pod 'libPusher', :head
        end
        @resolver = Resolver.new(podfile, @lockfile, stub('sandbox'))
        @resolver.update_mode = true
        @resolver.resolve
        @resolver.should_install?("libPusher").should.be.true
      end

      # TODO: stub the specification resolution for the sandbox
      xit "it always suggests to update pods from external sources" do
        podfile = Podfile.new do
          platform :ios
          pod 'libPusher', :git => "example.com"
        end
        @resolver = Resolver.new(podfile, @lockfile, stub('sandbox'))
        @resolver.update_mode = true
        @resolver.resolve
        @resolver.should_install?("libPusher").should.be.true
      end
    end

  end
end
