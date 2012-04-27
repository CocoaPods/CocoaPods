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
        xcodeproj 'MyProject'
        dependency 'JSONKit'
      end).target_installers.first.xcconfig.to_hash
    end

    it "sets the header search paths where installed Pod headers can be found" do
      @xcconfig['ALWAYS_SEARCH_USER_PATHS'].should == 'YES'
    end

    it "configures the project to load all members that implement Objective-c classes or categories from the static library" do
      @xcconfig['OTHER_LDFLAGS'].should == '-ObjC'
    end

    it "sets the PODS_ROOT build variable" do
      @xcconfig['PODS_ROOT'].should.not == nil
    end
  end

  it "generates a BridgeSupport metadata file from all the pod headers" do
    podfile = Pod::Podfile.new do
      platform :osx
      dependency 'ASIHTTPRequest'
    end
    installer = Pod::Installer.new(podfile)
    pods = installer.activated_specifications.map do |spec|
      Pod::LocalPod.new(spec, installer.sandbox, podfile.target_definitions[:default].platform)
    end
    expected = pods.map { |pod| pod.header_files }.flatten.map { |header| config.project_pods_root + header }
    expected.size.should > 0
    installer.target_installers.first.bridge_support_generator_for(pods, installer.sandbox).headers.should == expected
  end

  it "omits empty target definitions" do
    podfile = Pod::Podfile.new do
      platform :ios
      target :not_empty do
        dependency 'JSONKit'
      end
    end
    installer = Pod::Installer.new(podfile)
    installer.target_installers.map(&:target_definition).map(&:name).should == [:not_empty]
  end
end
