require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Installer" do
  before do
    @config_before = config
    Pod::Config.instance = nil
    config.silent = true
    config.repos_dir = fixture('spec-repos')
    config.project_pods_root = fixture('integration')
  end

  after do
    Pod::Config.instance = @config_before
  end

  describe ", by default," do
    before do
      @xcconfig = Pod::Installer.new(Pod::Podfile.new do
        platform :ios
        dependency 'JSONKit'
      end).target_installers.first.xcconfig.to_hash
    end

    it "sets the header search paths where installed Pod headers can be found" do
      @xcconfig['HEADER_SEARCH_PATHS'].should == '"$(PODS_ROOT)/Headers"'
      @xcconfig['ALWAYS_SEARCH_USER_PATHS'].should == 'YES'
    end

    it "configures the project to load categories from the static library" do
      @xcconfig['OTHER_LDFLAGS'].should == '-ObjC -all_load'
    end
  end

  it "generates a BridgeSupport metadata file from all the pod headers" do
    podfile = Pod::Podfile.new do
      platform :osx
      dependency 'ASIHTTPRequest'
    end
    config.rootspec = podfile
    expected = []
    installer = Pod::Installer.new(podfile)
    pods = installer.activated_specifications.map do |spec|
      spec.header_files.each do |header|
        expected << config.project_pods_root + header
      end
      Pod::LocalPod.new(spec, installer.sandbox)
    end
    installer.target_installers.first.bridge_support_generator_for(pods, installer.sandbox).headers.should == expected
  end

  it "omits empty target definitions" do
    podfile = Pod::Podfile.new do
      platform :ios
      target :not_empty do
        dependency 'JSONKit'
      end
    end
    config.rootspec = podfile
    installer = Pod::Installer.new(podfile)
    installer.target_installers.map(&:target_definition).map(&:name).should == [:not_empty]
  end
end
