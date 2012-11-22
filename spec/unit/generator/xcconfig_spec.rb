require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Generator::XCConfig do
    before do
      specification = fixture_spec('banana-lib/BananaLib.podspec')
      @pod          = Pod::LocalPod.new(specification, config.sandbox, :ios)
      @generator    = Generator::XCConfig.new(config.sandbox, [@pod], './Pods')

    end

    it "returns the sandbox" do
      @generator.sandbox.class.should == Sandbox
    end

    it "returns the pods" do
      @generator.pods.should == [@pod]
    end

    it "returns the path of the pods root relative to the user project" do
      @generator.relative_pods_root.should == './Pods'
    end

    #-----------------------------------------------------------------------#

    before do
      @xcconfig = @generator.generate
    end

    it "generates the xcconfig" do
      @xcconfig.class.should == Xcodeproj::Config
    end

    it 'adds the sandbox header search paths to the xcconfig, with quotes' do
      @xcconfig.to_hash['PODS_BUILD_HEADERS_SEARCH_PATHS'].should.include("\"#{config.sandbox.build_headers.search_paths.join('" "')}\"")
    end

    it 'does not add the -fobjc-arc to OTHER_LDFLAGS by default as Xcode 4.3.2 does not support it' do
      @xcconfig.to_hash['OTHER_LDFLAGS'].split(" ").should.not.include("-fobjc-arc")
    end

    it 'adds the -fobjc-arc to OTHER_LDFLAGS if any pods require arc (to support non-ARC projects on iOS 4.0)' do
      @generator.set_arc_compatibility_flag = true
      @pod.top_specification.stubs(:requires_arc).returns(true)
      @xcconfig = @generator.generate
      @xcconfig.to_hash['OTHER_LDFLAGS'].split(" ").should.include("-fobjc-arc")
    end

    #-----------------------------------------------------------------------#

    it 'returns the settings that the pods project needs to override' do
      Generator::XCConfig.pods_project_settings.should.not.be.nil
    end

    it 'overrides the relative path of the pods root in the Pods project' do
      Generator::XCConfig.pods_project_settings['PODS_ROOT'].should == '${SRCROOT}'
    end

    it 'overrides the headers search path of the pods project to the build headers folder' do
      expected = '${PODS_BUILD_HEADERS_SEARCH_PATHS}'
      Generator::XCConfig.pods_project_settings['PODS_HEADERS_SEARCH_PATHS'].should == expected
    end

    #-----------------------------------------------------------------------#

    extend SpecHelper::TemporaryDirectory

    it "saves the xcconfig" do
      path = temporary_directory + 'sample.xcconfig'
      @generator.save_as(path)
      generated = Xcodeproj::Config.new(path)
      generated.class.should == Xcodeproj::Config
    end

  end
end
