require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Installer::AggregateTargetInstaller do
    describe "In General" do
      before do
        @podfile = Podfile.new do
          platform :ios
          xcodeproj 'dummy'
        end
        @target_definition = @podfile.target_definitions['Pods']
        @project = Project.new(environment.sandbox.project_path)

        environment.sandbox.project = @project
        path_list = Sandbox::PathList.new(fixture('banana-lib'))
        @spec = fixture_spec('banana-lib/BananaLib.podspec')
        file_accessor = Sandbox::FileAccessor.new(path_list, @spec.consumer(:ios))
        @project.add_pod_group('BananaLib', fixture('banana-lib'))
        group = @project.group_for_spec('BananaLib')
        file_accessor.source_files.each do |file|
          @project.add_file_reference(file, group)
        end

        @target = AggregateTarget.new(@target_definition, environment.sandbox)
        @target.stubs(:platform).returns(Platform.new(:ios, '6.0'))
        @target.user_project_path = environment.sandbox.root + '../user_project.xcodeproj'
        @target.client_root = environment.sandbox.root.dirname
        @target.user_build_configurations = { 'Debug' => :debug, 'Release' => :release, 'AppStore' => :release, 'Test' => :debug }

        @pod_target = PodTarget.new([@spec], @target_definition, environment.sandbox)
        @pod_target.stubs(:platform).returns(Platform.new(:ios, '6.0'))
        @pod_target.user_build_configurations = @target.user_build_configurations
        @pod_target.file_accessors = [file_accessor]

        @target.pod_targets = [@pod_target]

        @installer = Installer::AggregateTargetInstaller.new(environment.sandbox, @target)

        @spec.prefix_header_contents = '#import "BlocksKit.h"'
      end

      it "adds file references for the support files of the target" do
        @installer.install!
        group = @project.support_files_group['Pods']
        group.children.map(&:display_name).sort.should == [
          "Pods-acknowledgements.markdown",
          "Pods-acknowledgements.plist",
          "Pods-dummy.m",
          "Pods-environment.h",
          "Pods-resources.sh",
          "Pods.xcconfig"
        ]
      end

      #--------------------------------------#

      it 'adds the target for the static library to the project' do
        @installer.install!
        @project.targets.count.should == 1
        @project.targets.first.name.should == @target_definition.label
      end

      it "adds the user build configurations to the target" do
        @installer.install!
        target = @project.targets.first
        target.build_settings('Test')["VALIDATE_PRODUCT"].should == nil
        target.build_settings('AppStore')["VALIDATE_PRODUCT"].should == "YES"
      end

      it "sets VALIDATE_PRODUCT to YES for the Release configuration for iOS targets" do
        @installer.install!
        target = @project.targets.first
        target.build_settings('Release')["VALIDATE_PRODUCT"].should == "YES"
      end

      it "sets the platform and the deployment target for iOS targets" do
        @installer.install!
        target = @project.targets.first
        target.platform_name.should == :ios
        target.deployment_target.should == "6.0"
        target.build_settings('Debug')["IPHONEOS_DEPLOYMENT_TARGET"].should == "6.0"
        target.build_settings('AppStore')["IPHONEOS_DEPLOYMENT_TARGET"].should == "6.0"
      end

      it "sets the platform and the deployment target for OS X targets" do
        @target.stubs(:platform).returns(Platform.new(:osx, '10.8'))
        @installer.install!
        target = @project.targets.first
        target.platform_name.should == :osx
        target.deployment_target.should == "10.8"
        target.build_settings('Debug')["MACOSX_DEPLOYMENT_TARGET"].should == "10.8"
        target.build_settings('AppStore')["MACOSX_DEPLOYMENT_TARGET"].should == "10.8"
      end

      it "adds the user's build configurations to the target" do
        @installer.install!
        @project.targets.first.build_configurations.map(&:name).sort.should == %w{ AppStore Debug Release Test }
      end

      it "it creates different hash instances for the build settings of various build configurations" do
        @installer.install!
        build_settings = @project.targets.first.build_configurations.map(&:build_settings)
        build_settings.map(&:object_id).uniq.count.should == 4
      end

      it "does not enable the GCC_WARN_INHIBIT_ALL_WARNINGS flag by default" do
        @installer.install!
        @installer.library.target.build_configurations.each do |config|
          config.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'].should.be.nil
        end
      end

      #--------------------------------------#

      it "creates the xcconfig file" do
        @installer.install!
        file = environment.sandbox.root + @target.xcconfig_path
        xcconfig = Xcodeproj::Config.new(file)
        xcconfig.to_hash['PODS_ROOT'].should == '${SRCROOT}/Pods'
      end

      it "creates a header for the target which contains the information about the installed Pods" do
        @installer.install!
        file = environment.sandbox.root + 'Pods-environment.h'
        contents = file.read
        contents.should.include?('#define COCOAPODS_POD_AVAILABLE_BananaLib')
        contents.should.include?('#define COCOAPODS_VERSION_MAJOR_BananaLib 1')
        contents.should.include?('#define COCOAPODS_VERSION_MINOR_BananaLib 0')
        contents.should.include?('#define COCOAPODS_VERSION_PATCH_BananaLib 0')
      end

      it "creates a bridge support file" do
        Podfile.any_instance.stubs(:generate_bridge_support? => true)
        Generator::BridgeSupport.any_instance.expects(:save_as).once
        @installer.install!
      end

      it "creates a create copy resources script" do
        @installer.install!
        script = environment.sandbox.root + 'Pods-resources.sh'
        script.read.should.include?('logo-sidebar.png')
      end

      xit "adds the resources bundles to the copy resources script" do

      end

      xit "adds the bridge support file to the copy resources script, if one was created" do

      end

      it "creates the acknowledgements files " do
        @installer.install!
        markdown = environment.sandbox.root + 'Pods-acknowledgements.markdown'
        markdown.read.should.include?('Permission is hereby granted')
        plist = environment.sandbox.root + 'Pods-acknowledgements.plist'
        plist.read.should.include?('Permission is hereby granted')
      end

      it "creates a dummy source to ensure the creation of a single base library" do
        @installer.install!
        build_files = @installer.library.target.source_build_phase.files
        build_file = build_files.find { |bf| bf.file_ref.path.include?('Pods-dummy.m') }
        build_file.should.be.not.nil
        build_file.file_ref.path.should == 'Pods-dummy.m'
        dummy = environment.sandbox.root + 'Pods-dummy.m'
        dummy.read.should.include?('@interface PodsDummy_Pods')
      end
    end
  end
end

