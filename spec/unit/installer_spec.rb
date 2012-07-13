require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Installer do
    before do
      config.repos_dir = fixture('spec-repos')
      config.project_pods_root = fixture('integration')
    end

    describe "by default" do
      before do
        podfile = Podfile.new do
          platform :ios
          xcodeproj 'MyProject'
          pod 'JSONKit'
        end
        @xcconfig = Installer.new(podfile).target_installers.first.xcconfig.to_hash
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
      podfile = Podfile.new do
        platform :osx
        pod 'ASIHTTPRequest'
      end
      installer = Installer.new(podfile)
      pods = installer.specifications.map do |spec|
        LocalPod.new(spec, installer.sandbox, podfile.target_definitions[:default].platform)
      end
      expected = pods.map { |pod| pod.header_files }.flatten.map { |header| config.project_pods_root + header }
      expected.size.should > 0
      installer.target_installers.first.bridge_support_generator_for(pods, installer.sandbox).headers.should == expected
    end

    it "omits empty target definitions" do
      podfile = Podfile.new do
        platform :ios
        target :not_empty do
          pod 'JSONKit'
        end
      end
      installer = Installer.new(podfile)
      installer.target_installers.map(&:target_definition).map(&:name).should == [:not_empty]
    end

    it "adds the user's build configurations" do
      path = fixture('SampleProject/SampleProject.xcodeproj')
      podfile = Podfile.new do
        platform :ios
        xcodeproj path, 'App Store' => :release
      end
      installer = Installer.new(podfile)
      installer.project.build_configurations.map(&:name).sort.should == ['App Store', 'Debug', 'Release', 'Test']
    end

    it "forces downloading of the `bleeding edge' version of a pod" do
      podfile = Podfile.new do
        platform :ios
        pod 'JSONKit', :head
      end
      installer = Installer.new(podfile)
      pod = installer.pods.first

      downloader = stub('Downloader')
      Downloader.stubs(:for_pod).returns(downloader)

      downloader.expects(:download_head)
      installer.download_pod(pod)
    end
  end
end
