require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  module Generator
    module XCConfig
      describe PublicPodXCConfig do

        before do
          @spec = fixture_spec('banana-lib/BananaLib.podspec')
          @pod_target = Target.new('Pods-BananaLib')
          @sut = PublicPodXCConfig.new(@pod_target, config.sandbox.root)
          file_accessors = [Sandbox::FileAccessor.new(fixture('banana-lib'), @spec.consumer(:ios))]
          @pod_target.stubs(:file_accessors).returns(file_accessors)
        end

        it "generates the xcconfig" do
          xcconfig = @sut.generate
          xcconfig.class.should == Xcodeproj::Config
        end

        it "includes the xcconfig of the specifications" do
          @spec.xcconfig = { 'OTHER_LDFLAGS' => '-no_compact_unwind' }
          xcconfig = @sut.generate
          xcconfig.to_hash["OTHER_LDFLAGS"].should.include('-no_compact_unwind')
        end

        it "includes the libraries for the specifications" do
          @spec.libraries = ['xml2']
          xcconfig = @sut.generate
          xcconfig.to_hash["OTHER_LDFLAGS"].should.include('-lxml2')
        end

        it "includes the frameworks of the specifications" do
          @spec.frameworks = ['QuartzCore']
          xcconfig = @sut.generate
          xcconfig.to_hash["OTHER_LDFLAGS"].should.include('-framework QuartzCore')
        end

        it "includes the weak-frameworks of the specifications" do
          @spec.weak_frameworks = ['iAd']
          xcconfig = @sut.generate
          xcconfig.to_hash["OTHER_LDFLAGS"].should.include('-weak_framework iAd')
        end

        it "includes the developer frameworks search paths when SenTestingKit is detected" do
          @spec.xcconfig = { 'OTHER_LDFLAGS' => '-no_compact_unwind' }
          @spec.frameworks = ['SenTestingKit']
          xcconfig = @sut.generate
          framework_search_paths = xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS']
          framework_search_paths.should.include('$(SDKROOT)/Developer')
        end

        it "doesn't include the developer frameworks if already present" do
          @spec.xcconfig = { 'FRAMEWORK_SEARCH_PATHS' => '"$(SDKROOT)/Developer/Library/Frameworks" "$(DEVELOPER_LIBRARY_DIR)/Frameworks"' }
          @spec.frameworks = ['SenTestingKit']
          xcconfig = @sut.generate
          framework_search_paths = xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].split(' ')
          framework_search_paths.select { |path| path == '"$(SDKROOT)/Developer/Library/Frameworks"'}.count.should == 1
          framework_search_paths.select { |path| path == '"$(DEVELOPER_LIBRARY_DIR)/Frameworks"'}.count.should == 1
        end

        it "includes the build settings of the frameworks bundles of the spec" do
          @sut.stubs(:sandbox_root).returns(fixture(''))
          xcconfig = @sut.generate
          xcconfig.to_hash["FRAMEWORK_SEARCH_PATHS"].should.include?('"$(PODS_ROOT)/banana-lib"')
        end

        it "includes the build settings of the libraries shipped with the spec" do
          @sut.stubs(:sandbox_root).returns(fixture(''))
          xcconfig = @sut.generate
          xcconfig.to_hash["LIBRARY_SEARCH_PATHS"].should.include?('"$(PODS_ROOT)/banana-lib"')
        end

        #---------------------------------------------------------------------#

        before do
          xcconfig = @sut.generate
          @path = temporary_directory + 'sample.xcconfig'
          @sut.save_as(@path)
        end

        it "saves the xcconfig" do
          generated = Xcodeproj::Config.new(@path)
          generated.class.should == Xcodeproj::Config
        end

        it "writes the xcconfig with a prefix computed from the target definition and root spec" do
          generated = Xcodeproj::Config.new(@path)
          generated.to_hash.each { |k, v| k.should.start_with('PODS_BANANALIB_') }
        end

        #---------------------------------------------------------------------#

      end
    end
  end
end
