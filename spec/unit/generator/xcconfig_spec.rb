require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Generator::XCConfig do
    before do
      @spec = fixture_spec('banana-lib/BananaLib.podspec')
      @consumer = @spec.consumer(:ios)
      @generator = Generator::XCConfig.new(config.sandbox, [@consumer], './Pods')
    end

    it "returns the sandbox" do
      @generator.sandbox.class.should == Sandbox
    end

    it "returns the pods" do
      names = @generator.spec_consumers.should == [@consumer]
    end

    it "returns the path of the pods root relative to the user project" do
      @generator.relative_pods_root.should == './Pods'
    end

    #-----------------------------------------------------------------------#

    before do
      @spec.xcconfig = { 'OTHER_LDFLAGS' => '-no_compact_unwind' }
      @spec.frameworks = ['QuartzCore']
      @spec.weak_frameworks = ['iAd']
      @spec.libraries = ['xml2']
      @xcconfig = @generator.generate
    end

    it "generates the xcconfig" do
      @xcconfig.class.should == Xcodeproj::Config
    end

    it "sets to always search the user paths" do
      @xcconfig.to_hash['ALWAYS_SEARCH_USER_PATHS'].should == 'YES'
    end
    
    it "redirects the OTHER_LDFLAGS to the pod variable PODS_LDFLAGS" do
      @xcconfig.to_hash['OTHER_LDFLAGS'].should == '${PODS_LDFLAGS}'
    end

    it "configures the project to load all members that implement Objective-c classes or categories from the static library" do
      @xcconfig.to_hash['PODS_LDFLAGS'].should.include '-ObjC'
    end

    it 'does not add the -fobjc-arc to PODS_LDFLAGS by default as Xcode 4.3.2 does not support it' do
      @xcconfig.to_hash['PODS_LDFLAGS'].should.not.include("-fobjc-arc")
    end

    it 'adds the -fobjc-arc to PODS_LDFLAGS if any pods require arc (to support non-ARC projects on iOS 4.0)' do
      @generator.set_arc_compatibility_flag = true
      @consumer.stubs(:requires_arc).returns(true)
      xcconfig = @generator.generate
      xcconfig.to_hash['PODS_LDFLAGS'].split(" ").should.include("-fobjc-arc")
    end

    it "sets the PODS_ROOT build variable" do
      @xcconfig.to_hash['PODS_ROOT'].should.not == nil
    end

    it "redirects the HEADERS_SEARCH_PATHS to the pod variable" do
      @xcconfig.to_hash['HEADER_SEARCH_PATHS'].should =='${PODS_HEADERS_SEARCH_PATHS}'
    end

    it "sets the PODS_HEADERS_SEARCH_PATHS to look for the public headers as it is overridden in the Pods project" do
      @xcconfig.to_hash['PODS_HEADERS_SEARCH_PATHS'].should =='${PODS_PUBLIC_HEADERS_SEARCH_PATHS}'
    end
    it 'adds the sandbox build headers search paths to the xcconfig, with quotes' do
      expected = "\"#{config.sandbox.build_headers.search_paths.join('" "')}\""
      @xcconfig.to_hash['PODS_BUILD_HEADERS_SEARCH_PATHS'].should == expected
    end

    it 'adds the sandbox public headers search paths to the xcconfig, with quotes' do
      expected = "\"#{config.sandbox.public_headers.search_paths.join('" "')}\""
      @xcconfig.to_hash['PODS_PUBLIC_HEADERS_SEARCH_PATHS'].should == expected
    end

    it 'adds the COCOAPODS macro definition' do
      @xcconfig.to_hash['GCC_PREPROCESSOR_DEFINITIONS'].should == 'COCOAPODS=1'
    end

    it "includes the xcconfig of the specifications" do
      @xcconfig.to_hash['PODS_LDFLAGS'].should.include('-no_compact_unwind')
    end

    it "includes the libraries for the specifications" do
      @xcconfig.to_hash['PODS_LDFLAGS'].should.include('-lxml2')
    end

    it "includes the frameworks of the specifications" do
      @xcconfig.to_hash['PODS_LDFLAGS'].should.include('-framework QuartzCore')
    end

    it "includes the weak-frameworks of the specifications" do
      @xcconfig.to_hash['PODS_LDFLAGS'].should.include('-weak_framework iAd')
    end

    it "includes the developer frameworks search paths when SenTestingKit is detected" do
      spec = fixture_spec('banana-lib/BananaLib.podspec')
      consumer = spec.consumer(:ios)
      generator = Generator::XCConfig.new(config.sandbox, [consumer], './Pods')
      spec.xcconfig = { 'OTHER_LDFLAGS' => '-no_compact_unwind' }
      spec.frameworks = ['SenTestingKit']
      xcconfig = generator.generate
      xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should == '$(inherited) "$(SDKROOT)/Developer/Library/Frameworks" "$(DEVELOPER_LIBRARY_DIR)/Frameworks"'
    end

    it "doesn't include the developer frameworks if already present" do
      spec = fixture_spec('banana-lib/BananaLib.podspec')
      consumer_1 = spec.consumer(:ios)
      consumer_2 = spec.consumer(:ios)
      generator = Generator::XCConfig.new(config.sandbox, [consumer_1, consumer_2], './Pods')
      spec.frameworks = ['SenTestingKit']
      xcconfig = generator.generate
      xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should == '$(inherited) "$(SDKROOT)/Developer/Library/Frameworks" "$(DEVELOPER_LIBRARY_DIR)/Frameworks"'
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

    it "saves the xcconfig" do
      path = temporary_directory + 'sample.xcconfig'
      @generator.save_as(path)
      generated = Xcodeproj::Config.new(path)
      generated.class.should == Xcodeproj::Config
    end

  end
end
