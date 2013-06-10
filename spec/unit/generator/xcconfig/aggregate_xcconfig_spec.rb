require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Generator::AggregateXCConfig do
    before do
      @spec = fixture_spec('banana-lib/BananaLib.podspec')
      @consumer = @spec.consumer(:ios)
      target_definition = Podfile::TargetDefinition.new('Pods', nil)
      @target = AggregateTarget.new(target_definition, config.sandbox)
      @target.client_root = config.sandbox.root.dirname
      @target.stubs(:platform).returns(:ios)
      @pod_target = PodTarget.new([@spec], target_definition, config.sandbox)
      @pod_target.stubs(:platform).returns(:ios)
      @pod_target.stubs(:spec_consumers).returns([@consumer])
      @target.pod_targets = [@pod_target]
      @generator = Generator::AggregateXCConfig.new(@target)
    end

    it "returns the sandbox" do
      @generator.sandbox.class.should == Sandbox
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

    it "sets to always search the user paths" do
      @xcconfig.to_hash['ALWAYS_SEARCH_USER_PATHS'].should == 'YES'
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
      expected = "\"#{config.sandbox.public_headers.search_paths.join('" "')}\""
      @xcconfig.to_hash['HEADER_SEARCH_PATHS'].should == expected
    end

    it 'adds the COCOAPODS macro definition' do
      @xcconfig.to_hash['GCC_PREPROCESSOR_DEFINITIONS'].should.include 'COCOAPODS=1'
    end

    it 'inherits the parent GCC_PREPROCESSOR_DEFINITIONS value' do
      @xcconfig.to_hash['GCC_PREPROCESSOR_DEFINITIONS'].should.include '$(inherited)'
    end

    it 'adds the pod namespaced configuration items' do
      @xcconfig.to_hash['OTHER_LDFLAGS'].should.include("${#{@pod_target.xcconfig_prefix}OTHER_LDFLAGS}")
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

    it "includes the namespaced public pod xcconfig file" do
      generated = Xcodeproj::Config.new(@path)
      generated.includes.should.include("#{@pod_target.label}")
    end

  end
end
