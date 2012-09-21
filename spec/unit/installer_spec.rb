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

        sandbox = Sandbox.new(fixture('integration'))
        resolver = Resolver.new(podfile, nil, sandbox)
        @xcconfig = Installer.new(resolver).target_installers.first.xcconfig.to_hash
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

      it "generates a BridgeSupport metadata file from all the pod headers" do
        podfile = Podfile.new do
          platform :osx
          pod 'ASIHTTPRequest'
        end

        sandbox = Sandbox.new(fixture('integration'))
        resolver = Resolver.new(podfile, nil, sandbox)
        installer = Installer.new(resolver)
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
        resolver = Resolver.new(podfile, nil, Sandbox.new(fixture('integration')))
        installer = Installer.new(resolver)
        installer.target_installers.map(&:target_definition).map(&:name).should == [:not_empty]
      end

      it "adds the user's build configurations" do
        path = fixture('SampleProject/SampleProject.xcodeproj')
        podfile = Podfile.new do
          platform :ios
          xcodeproj path, 'App Store' => :release
        end
        resolver = Resolver.new(podfile, nil, Sandbox.new(fixture('integration')))
        installer = Installer.new(resolver)
        installer.project.build_configurations.map(&:name).sort.should == ['App Store', 'Debug', 'Release', 'Test']
      end

      it "forces downloading of the `bleeding edge' version of a pod" do
        podfile = Podfile.new do
          platform :ios
          pod 'JSONKit', :head
        end
        resolver = Resolver.new(podfile, nil, Sandbox.new(fixture('integration')))
        installer = Installer.new(resolver)
        pod = installer.pods.first

        downloader = stub('Downloader')
        Downloader.stubs(:for_pod).returns(downloader)

        downloader.expects(:download_head)
        installer.download_pod(pod)
      end
    end

    describe "concerning multiple pods originating form the same spec" do
      extend SpecHelper::Fixture

      before do
        sandbox = temporary_sandbox
        Pod::Config.instance.project_pods_root = sandbox.root
        Pod::Config.instance.integrate_targets = false
        podspec_path = fixture('integration/Reachability/Reachability.podspec')
        podfile = Podfile.new do
          platform :osx
          pod 'Reachability', :podspec => podspec_path.to_s
          target :debug do
            pod 'Reachability'
          end
        end
        resolver = Resolver.new(podfile, nil, sandbox)
        @installer = Installer.new(resolver)
      end

      # The double installation leads to a bug when different subspecs are
      # activated for the same pod. We need a way to install a pod only
      # once while keeping all the files of the actived subspecs.
      #
      # LocalPodSet?
      #
      it "installs the pods only once" do
        LocalPod.any_instance.stubs(:downloaded?).returns(false)
        Downloader::GitHub.any_instance.expects(:download).once
        @installer.install!
      end

      it "cleans a pod only once" do
        LocalPod.any_instance.expects(:clean!).once
        @installer.install!
      end

      it "adds the files of the pod to the Pods project only once" do
        @installer.install!
        group = @installer.project.pods.groups.where(:name => 'Reachability')
        group.files.map(&:name).should == ["Reachability.h", "Reachability.m"]
      end

      it "lists a pod only once" do
        reachability_pods = @installer.pods.map(&:to_s).select { |s| s.include?('Reachability') }
        reachability_pods.count.should == 1
      end
    end

    describe "concerning namespacing" do
      extend SpecHelper::Fixture

      before do
        sandbox = temporary_sandbox
        Pod::Config.instance.project_pods_root = sandbox.root
        Pod::Config.instance.integrate_targets = false
        podspec_path = fixture('chameleon')
        podfile = Podfile.new do
          platform :osx
          pod 'Chameleon', :local => podspec_path
        end
        resolver   = Resolver.new(podfile, nil, sandbox)
        @installer = Installer.new(resolver)
      end

      it "namespaces local pods" do
        @installer.install!
        group = @installer.project.groups.where(:name => 'Local Pods')
        group.groups.map(&:name).sort.should == %w| Chameleon |
      end

      it "namespaces subspecs" do
        @installer.install!
        group = @installer.project.groups.where(:name => 'Chameleon')
        group.groups.map(&:name).sort.should == %w| AVFoundation AssetsLibrary MediaPlayer MessageUI StoreKit UIKit |
      end
    end
  end
end
