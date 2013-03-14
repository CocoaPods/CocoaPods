require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Resolver do
    describe "In general" do
      before do
        @podfile = Podfile.new do
          platform :ios
          pod 'BlocksKit', '1.5.2'
        end
        locked_deps = [Dependency.new('BlocksKit', '1.5.2')]
        @resolver = Resolver.new(config.sandbox, @podfile, locked_deps)
      end

      it "returns the sandbox" do
        @resolver.sandbox.should == config.sandbox
      end

      it "returns the podfile" do
        @resolver.podfile.should == @podfile
      end

      it "returns the locked dependencies" do
        @resolver.locked_dependencies.should == [Dependency.new('BlocksKit', '1.5.2')]
      end

      #--------------------------------------#

      it "resolves the specification of the podfile" do
        target_definition = @podfile.target_definitions['Pods']
        specs = @resolver.resolve[target_definition]
        specs.map(&:to_s).should == [
          "A2DynamicDelegate (2.0.2)",
          "BlocksKit (1.5.2)",
          "libffi (3.0.11)"
        ]
      end

      it "returns the resolved specifications grouped by target definition" do
        @resolver.resolve
        target_definition = @podfile.target_definitions['Pods']
        specs = @resolver.specs_by_target[target_definition]
        specs.map(&:to_s).should == [
          "A2DynamicDelegate (2.0.2)",
          "BlocksKit (1.5.2)",
          "libffi (3.0.11)"
        ]
      end

      it "it resolves specifications from external sources" do
        podspec = fixture('integration/Reachability/Reachability.podspec')
        spec = Specification.from_file(podspec)
        config.sandbox.expects(:specification).with('Reachability').returns(spec)
        podfile = Podfile.new do
          platform :ios
          pod "Reachability", :podspec => podspec
        end
        resolver = Resolver.new(config.sandbox, podfile)
        resolver.resolve
        specs = resolver.specs_by_target.values.flatten
        specs.map(&:to_s).should == ['Reachability (3.0.0)']
      end
    end

    #-------------------------------------------------------------------------#

    describe "Resolution" do
      before do
        @podfile = Podfile.new do
          platform :ios, '6.0'
          pod 'BlocksKit', '1.5.2'
        end
        @resolver = Resolver.new(config.sandbox, @podfile)
      end

      it "cross resolves dependencies" do
        @podfile = Podfile.new do
          platform :ios, '6.0'
          pod 'AFNetworking',    '<  0.9.2' # 0.9.1 exits
          pod 'AFQuickLookView', '=  0.1.0' # requires  'AFNetworking', '>= 0.9.0'
        end

        resolver = Resolver.new(config.sandbox, @podfile)
        specs = resolver.resolve.values.flatten.map(&:to_s).sort
        specs.should == ["AFNetworking (0.9.1)", "AFQuickLookView (0.1.0)"]
      end

      it "holds the context state, such as cached specification sets" do
        @resolver.resolve
        cached_sets = @resolver.send(:cached_sets)
        cached_sets.values.sort_by(&:name).should == [
          SourcesManager.search_by_name('A2DynamicDelegate').first,
          SourcesManager.search_by_name('BlocksKit').first,
          SourcesManager.search_by_name('libffi').first
        ].sort_by(&:name)
      end

      it "raises once any of the dependencies does not match the platform of its podfile target" do
        Specification.any_instance.stubs(:available_platforms).returns([Platform.new(:ios, '999')])
        e = lambda { @resolver.resolve }.should.raise Informative
        e.message.should.match(/platform .* not compatible/)
      end

      it "does not raise if all dependencies are supported by the platform of the target definition" do
        lambda { @resolver.resolve }.should.not.raise
      end

      it "includes all the subspecs of a specification node" do
        @podfile = Podfile.new do
          platform :ios
          pod 'RestKit', '0.10.3'
        end
        resolver = Resolver.new(config.sandbox, @podfile)
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

      it "handles correctly subspecs from external sources" do
        @podfile = Podfile.new do
          platform :ios
          pod 'MainSpec/FirstSubSpec', :git => 'GIT-URL'
        end
        spec = Spec.new do |s|
          s.name         = 'MainSpec'
          s.version      = '1.2.3'
          s.platform     = :ios

          s.subspec 'FirstSubSpec' do |fss|
            fss.source_files = 'some/file'
            fss.subspec 'SecondSubSpec'
          end
        end
        config.sandbox.expects(:specification).with('MainSpec').returns(spec)
        resolver = Resolver.new(config.sandbox, @podfile)
        specs = resolver.resolve.values.flatten.map(&:name).sort
        specs.should == %w{ MainSpec/FirstSubSpec MainSpec/FirstSubSpec/SecondSubSpec }
      end

      it "marks a specification's version to be a HEAD version" do
        podfile = Podfile.new do
          platform :ios
          pod 'FileMD5Hash'
          pod 'JSONKit', :head
        end
        resolver = Resolver.new(config.sandbox, podfile)
        filemd5hash, jsonkit = resolver.resolve.values.first.sort_by(&:name)
        filemd5hash.version.should.not.be.head
        jsonkit.version.should.be.head
      end

      it "raises if it finds two conflicting dependencies" do
        podfile = Podfile.new do
          platform :ios
          pod 'JSONKit', "1.4"
          pod 'JSONKit', "1.5pre"
        end
        resolver = Resolver.new(config.sandbox, podfile)
        e = lambda {resolver.resolve}.should.raise Pod::Informative
        e.message.should.match(/already activated version/)
      end

      it "takes into account locked dependencies" do
        podfile = Podfile.new do
          platform :ios
          pod 'JSONKit', "<= 1.5pre"
        end
        resolver = Resolver.new(config.sandbox, podfile)
        version = resolver.resolve.values.flatten.first.version
        version.to_s.should == '1.5pre'

        locked_deps = [Dependency.new('JSONKit', "= 1.4")]
        resolver = Resolver.new(config.sandbox, podfile, locked_deps)
        version = resolver.resolve.values.flatten.first.version
        version.to_s.should == '1.4'
      end
    end


    #-------------------------------------------------------------------------#

  end
end
