require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Generator::XCConfig do

    before do
      target = stub(:sandbox => config.sandbox)
      @sut = Generator::XCConfig.new(target)
    end

    describe "#add_framework_build_settings" do
      it "adds the build settings of a framework to the given xcconfig" do
        framework_path = config.sandbox.root + 'Parse/Parse.framework'
        xcconfig = Xcodeproj::Config.new
        @sut.send(:add_framework_build_settings, framework_path, xcconfig)
        hash_config = xcconfig.to_hash
        hash_config['OTHER_LDFLAGS'].should == "-framework Parse"
        hash_config['FRAMEWORK_SEARCH_PATHS'].should == '"$(PODS_ROOT)/Parse"'
      end

      it "doesn't ovverides exiting linker flags" do
        framework_path = config.sandbox.root + 'Parse/Parse.framework'
        xcconfig = Xcodeproj::Config.new( { 'OTHER_LDFLAGS' => '-framework CoreAnimation' } )
        @sut.send(:add_framework_build_settings, framework_path, xcconfig)
        hash_config = xcconfig.to_hash
        hash_config['OTHER_LDFLAGS'].should == "-framework CoreAnimation -framework Parse"
      end

      it "doesn't ovverides exiting frameworks search paths" do
        framework_path = config.sandbox.root + 'Parse/Parse.framework'
        xcconfig = Xcodeproj::Config.new( { 'FRAMEWORK_SEARCH_PATHS' => '"path/to/frameworks"' } )
        @sut.send(:add_framework_build_settings, framework_path, xcconfig)
        hash_config = xcconfig.to_hash
        hash_config['FRAMEWORK_SEARCH_PATHS'].should == '"path/to/frameworks" "$(PODS_ROOT)/Parse"'

      end
    end

  end
end
