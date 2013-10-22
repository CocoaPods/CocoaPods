require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  module Generator
    module XCConfig
      describe AggregateXCConfig do

        before do
          @spec = fixture_spec('banana-lib/BananaLib.podspec')
          @consumer = @spec.consumer(:ios)
          target_definition = Podfile::TargetDefinition.new('Pods', nil)
          @target = AggregateTarget.new(target_definition, environment.sandbox)
          @target.client_root = environment.sandbox.root.dirname
          @target.stubs(:platform).returns(:ios)
          @pod_target = PodTarget.new([@spec], target_definition, environment.sandbox)
          @pod_target.stubs(:platform).returns(:ios)
          @pod_target.stubs(:spec_consumers).returns([@consumer])
          @target.pod_targets = [@pod_target]
          @generator = AggregateXCConfig.new(@target)
        end

        it "returns the path of the pods root relative to the user project" do
          @generator.target.relative_pods_root.should == '${SRCROOT}/Pods'
        end

        #-----------------------------------------------------------------------#

        before do
          @podfile = Podfile.new
          @target.target_definition.stubs(:podfile).returns(@podfile)
          @xcconfig = @generator.generate
        end

        it "generates the xcconfig" do
          @xcconfig.class.should == Xcodeproj::Config
        end

        it "configures the project to load all members that implement Objective-c classes or categories from the static library" do
          @xcconfig.to_hash['OTHER_LDFLAGS'].should.include '-ObjC'
        end

        it 'does not add the -fobjc-arc to OTHER_LDFLAGS by default as Xcode 4.3.2 does not support it' do
          @consumer.stubs(:requires_arc?).returns(true)
          @xcconfig.to_hash['OTHER_LDFLAGS'].should.not.include("-fobjc-arc")
        end

        it 'adds the -fobjc-arc to OTHER_LDFLAGS if any pods require arc and the podfile explicitly requires it' do
          @podfile.stubs(:set_arc_compatibility_flag?).returns(true)
          @consumer.stubs(:requires_arc?).returns(true)
          @xcconfig = @generator.generate
          @xcconfig.to_hash['OTHER_LDFLAGS'].split(" ").should.include("-fobjc-arc")
        end

        it "sets the PODS_ROOT build variable" do
          @xcconfig.to_hash['PODS_ROOT'].should == '${SRCROOT}/Pods'
        end

        it 'adds the sandbox public headers search paths to the xcconfig, with quotes' do
          expected = "\"#{environment.sandbox.public_headers.search_paths.join('" "')}\""
          @xcconfig.to_hash['HEADER_SEARCH_PATHS'].should == expected
        end

        it 'adds the COCOAPODS macro definition' do
          @xcconfig.to_hash['GCC_PREPROCESSOR_DEFINITIONS'].should.include 'COCOAPODS=1'
        end

        it 'inherits the parent GCC_PREPROCESSOR_DEFINITIONS value' do
          @xcconfig.to_hash['GCC_PREPROCESSOR_DEFINITIONS'].should.include '$(inherited)'
        end

        #-----------------------------------------------------------------------#

        before do
          @path = temporary_directory + 'sample.xcconfig'
          @generator.save_as(@path)
        end

        it "saves the xcconfig" do
          generated = Xcodeproj::Config.new(@path)
          generated.class.should == Xcodeproj::Config
        end

      end
    end
  end
end
