require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Generator::PublicPodXCConfig do
    before do
      @spec = fixture_spec('banana-lib/BananaLib.podspec')
      @target_definition = Podfile::TargetDefinition.new('Pods', nil)
      @pod_target = PodTarget.new([@spec], @target_definition, config.sandbox)
      @pod_target.stubs(:platform).returns(:ios)
      @generator = Generator::PublicPodXCConfig.new(@pod_target)

      @podfile = Podfile.new
      @spec.xcconfig = { 'OTHER_LDFLAGS' => '-no_compact_unwind' }
      @spec.frameworks = ['QuartzCore']
      @spec.weak_frameworks = ['iAd']
      @spec.libraries = ['xml2']
      file_accessors = [Sandbox::FileAccessor.new(nil, @spec.consumer(:ios))]
      framework_bundle_paths = [config.sandbox.root + 'BananaLib/BananaLib.framework']
      Sandbox::FileAccessor.any_instance.stubs(:framework_bundles).returns(framework_bundle_paths)

      @pod_target.target_definition.stubs(:podfile).returns(@podfile)
      @pod_target.stubs(:file_accessors).returns(file_accessors)

      @xcconfig = @generator.generate
    end

    it "generates the xcconfig" do
      @xcconfig.class.should == Xcodeproj::Config
    end

    it "includes the xcconfig of the specifications" do
      @xcconfig.to_hash["OTHER_LDFLAGS"].should.include('-no_compact_unwind')
    end

    it "includes the libraries for the specifications" do
      @xcconfig.to_hash["OTHER_LDFLAGS"].should.include('-lxml2')
    end

    it "includes the frameworks of the specifications" do
      @xcconfig.to_hash["OTHER_LDFLAGS"].should.include('-framework QuartzCore')
    end

    it "includes the weak-frameworks of the specifications" do
      @xcconfig.to_hash["OTHER_LDFLAGS"].should.include('-weak_framework iAd')
    end

    it "includes the developer frameworks search paths when SenTestingKit is detected" do
      @spec.xcconfig = { 'OTHER_LDFLAGS' => '-no_compact_unwind' }
      @spec.frameworks = ['SenTestingKit']
      xcconfig = @generator.generate
      xcconfig.to_hash["FRAMEWORK_SEARCH_PATHS"].should == '$(inherited) "$(SDKROOT)/Developer/Library/Frameworks" "$(DEVELOPER_LIBRARY_DIR)/Frameworks" "$(PODS_ROOT)/BananaLib"'
    end

    it "doesn't include the developer frameworks if already present" do
      spec = fixture_spec('banana-lib/BananaLib.podspec')
      pod_target = PodTarget.new([@spec, spec], @target_definition, config.sandbox)
      pod_target.stubs(:platform).returns(:ios)
      generator = Generator::PublicPodXCConfig.new(pod_target)
      spec.frameworks = ['SenTestingKit']
      file_accessors = [Sandbox::FileAccessor.new(nil, spec.consumer(:ios))]
      pod_target.stubs(:file_accessors).returns(file_accessors)

      xcconfig = generator.generate
      xcconfig.to_hash["FRAMEWORK_SEARCH_PATHS"].should == '$(inherited) "$(SDKROOT)/Developer/Library/Frameworks" "$(DEVELOPER_LIBRARY_DIR)/Frameworks" "$(PODS_ROOT)/BananaLib"'
    end

    it "includes the build settings of the frameworks bundles of the spec" do
      @spec.framework_bundles = ['BananaLib.framework']
      xcconfig = @generator.generate
      xcconfig.to_hash["FRAMEWORK_SEARCH_PATHS"].should.include?('"$(PODS_ROOT)/BananaLib"')
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

    it "writes the xcconfig with a prefix computed from the target definition and root spec" do
      generated = Xcodeproj::Config.new(@path)
      generated.to_hash.each { |k, v| k.should.start_with(@pod_target.xcconfig_prefix) }
    end

  end
end
