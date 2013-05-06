require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Generator::XCConfig do
    before do
      @spec = fixture_spec('banana-lib/BananaLib.podspec')
      @consumer = @spec.consumer(:ios)
      target_definition = Podfile::TargetDefinition.new('Pods', nil)
      @target = Target.new(target_definition, config.sandbox)
      @target.platform = :ios
      library_definition = Podfile::TargetDefinition.new(@spec.name, target_definition)
      @library = Target.new(library_definition, config.sandbox)
      @library.spec = @spec
      @library.platform = :ios
      @target.libraries = [@library]
      @generator = Generator::XCConfig.new(@library, [@consumer], './Pods')
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

    it "configures the project to load all members that implement Objective-c classes or categories from the static library" do
      @xcconfig.to_hash['OTHER_LDFLAGS'].should.include '-ObjC'
    end

    it 'does not add the -fobjc-arc to OTHER_LDFLAGS by default as Xcode 4.3.2 does not support it' do
      @xcconfig.to_hash['OTHER_LDFLAGS'].should.not.include("-fobjc-arc")
    end

    it 'adds the -fobjc-arc to OTHER_LDFLAGS if any pods require arc (to support non-ARC projects on iOS 4.0)' do
      @generator.set_arc_compatibility_flag = true
      @consumer.stubs(:requires_arc).returns(true)
      @xcconfig = @generator.generate
      @xcconfig.to_hash['OTHER_LDFLAGS'].split(" ").should.include("-fobjc-arc")
    end

    it "sets the PODS_ROOT build variable" do
      @xcconfig.to_hash['PODS_ROOT'].should.not == nil
    end

    it "redirects the HEADERS_SEARCH_PATHS to the pod variable" do
      @xcconfig.to_hash['HEADER_SEARCH_PATHS'].should =='${PODS_HEADERS_SEARCH_PATHS}'
    end

    it "sets the PODS_HEADERS_SEARCH_PATHS to look for public and build headers for per spec library targets" do
      @xcconfig.to_hash['PODS_HEADERS_SEARCH_PATHS'].should =='${PODS_BUILD_HEADERS_SEARCH_PATHS} ${PODS_PUBLIC_HEADERS_SEARCH_PATHS}'
    end

    it "sets the PODS_HEADERS_SEARCH_PATHS to look for the public headers for the integration library target" do
      xcconfig = Generator::XCConfig.new(@target, [], './Pods').generate
      xcconfig.to_hash['PODS_HEADERS_SEARCH_PATHS'].should =='${PODS_PUBLIC_HEADERS_SEARCH_PATHS}'
    end

    it 'adds the library build headers search paths to the xcconfig, with quotes' do
      expected = "\"#{@library.build_headers.search_paths.join('" "')}\""
      @xcconfig.to_hash['PODS_BUILD_HEADERS_SEARCH_PATHS'].should == expected
    end

    it 'adds the sandbox public headers search paths to the xcconfig, with quotes' do
      expected = "\"#{config.sandbox.public_headers.search_paths.join('" "')}\""
      @xcconfig.to_hash['PODS_PUBLIC_HEADERS_SEARCH_PATHS'].should == expected
    end

    it 'adds the COCOAPODS macro definition' do
      @xcconfig.to_hash['GCC_PREPROCESSOR_DEFINITIONS'].should == 'COCOAPODS=1'
    end

    it 'adds the pod namespaced configuration items' do
      @xcconfig.to_hash['OTHER_LDFLAGS'].should.include("${#{@library.xcconfig_prefix}OTHER_LDFLAGS}")
    end

    it "includes the xcconfig of the specifications" do
      @xcconfig.to_hash["#{@library.xcconfig_prefix}OTHER_LDFLAGS"].should.include('-no_compact_unwind')
    end

    it "includes the libraries for the specifications" do
      @xcconfig.to_hash["#{@library.xcconfig_prefix}OTHER_LDFLAGS"].should.include('-lxml2')
    end

    it "includes the frameworks of the specifications" do
      @xcconfig.to_hash["#{@library.xcconfig_prefix}OTHER_LDFLAGS"].should.include('-framework QuartzCore')
    end

    it "includes the weak-frameworks of the specifications" do
      @xcconfig.to_hash["#{@library.xcconfig_prefix}OTHER_LDFLAGS"].should.include('-weak_framework iAd')
    end

    it "includes the developer frameworks search paths when SenTestingKit is detected" do
      @spec.xcconfig = { 'OTHER_LDFLAGS' => '-no_compact_unwind' }
      @spec.frameworks = ['SenTestingKit']
      xcconfig = @generator.generate
      xcconfig.to_hash["#{@library.xcconfig_prefix}FRAMEWORK_SEARCH_PATHS"].should == '$(inherited) "$(SDKROOT)/Developer/Library/Frameworks" "$(DEVELOPER_LIBRARY_DIR)/Frameworks"'
    end

    it "doesn't include the developer frameworks if already present" do
      consumer_1 = @spec.consumer(:ios)
      consumer_2 = @spec.consumer(:ios)
      generator = Generator::XCConfig.new(@library, [consumer_1, consumer_2], './Pods')
      @spec.frameworks = ['SenTestingKit']
      xcconfig = generator.generate
      xcconfig.to_hash["#{@library.xcconfig_prefix}FRAMEWORK_SEARCH_PATHS"].should == '$(inherited) "$(SDKROOT)/Developer/Library/Frameworks" "$(DEVELOPER_LIBRARY_DIR)/Frameworks"'
    end

    #-----------------------------------------------------------------------#

    it 'sets the relative path of the pods root for spec libraries to ${SRCROOT}' do
      @xcconfig.to_hash['PODS_ROOT'].should == '${SRCROOT}'
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
