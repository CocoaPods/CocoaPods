require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Installer" do
  describe ", by default," do
    before do
      @xcconfig = Pod::Installer.new(Pod::Podfile.new { platform :ios }).target_installers.first.xcconfig.to_hash
    end

    it "sets the header search paths where installed Pod headers can be found" do
      @xcconfig['USER_HEADER_SEARCH_PATHS'].should == '"$(BUILT_PRODUCTS_DIR)/Pods"'
      @xcconfig['ALWAYS_SEARCH_USER_PATHS'].should == 'YES'
    end

    it "configures the project to load categories from the static library" do
      @xcconfig['OTHER_LDFLAGS'].should == '-ObjC -all_load'
    end
  end

  before do
    @config_before = config
    Pod::Config.instance = nil
    config.silent = true
    config.repos_dir = fixture('spec-repos')
    config.project_pods_root = fixture('integration')
    def config.ios?; true; end
    def config.osx?; false; end
  end

  after do
    Pod::Config.instance = @config_before
  end

  it "generates a BridgeSupport metadata file from all the pod headers" do
    spec = Pod::Podfile.new do
      platform :osx
      dependency 'ASIHTTPRequest'
    end
    expected = []
    installer = Pod::Installer.new(spec)
    installer.build_specifications.each do |spec|
      spec.header_files.each do |header|
        expected << config.project_pods_root + header
      end
    end
    installer.target_installers.first.bridge_support_generator.headers.should == expected
  end

  it "moves the compile and link phases to the end of the build phases list, so Pod headers are copied first and sources can use the same header dir structure" do
    podfile = Pod::Podfile.new do
      platform :osx
      dependency 'ASIHTTPRequest'
    end
    installer = Pod::Installer.new(podfile)
    installer.target_installers.first.install!
    phases = installer.project.targets.first.buildPhases
    phases.to_a.last(2).map(&:class).should == [Xcodeproj::Project::PBXSourcesBuildPhase, Xcodeproj::Project::PBXFrameworksBuildPhase]
  end
end
