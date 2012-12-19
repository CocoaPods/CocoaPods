require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe TargetInstaller = Installer::TargetInstaller do

    describe "In General" do

      before do
        @podfile = Podfile.new do
          platform :ios
          xcodeproj 'dummy'
        end
        @target_definition = @podfile.target_definitions[:default]
        @project = Project.new
        config.sandbox.project = @project

        @library = Library.new(@target_definition)
        @library.platform = Platform.new(:ios, '6.0')
        @library.support_files_root = config.sandbox.root
        @library.user_project_path  = config.sandbox.root + '../user_project.xcodeproj'
        @library.user_build_configurations = { 'Debug' => :debug, 'Release' => :release, 'AppStore' => :release, 'Test' => :debug }
        specification = fixture_spec('banana-lib/BananaLib.podspec')
        @pod = LocalPod.new(specification, config.sandbox, @library.platform)
        @library.local_pods = [@pod]

        @installer = TargetInstaller.new(config.sandbox, @library)

        specification.prefix_header_contents = '#import "BlocksKit.h"'
        @pod.stubs(:root).returns(Pathname.new(fixture('banana-lib')))
        @pod.add_file_references_to_project(@project)
      end

      it "adds file references for the support files of the target" do
        @installer.install!
        group = @project.support_files_group['Pods']
        group.children.map(&:display_name).sort.should == [
          "Pods-Acknowledgements.markdown",
          "Pods-Acknowledgements.plist",
          "Pods-Dummy.m",
          "Pods-prefix.pch",
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

      it "sets ARCHS to 'armv6 armv7' for both configurations if the deployment target is less than 4.3 for iOS targets" do
        @library.platform = Platform.new(:ios, '4.0')
        @installer.install!
        target = @project.targets.first
        target.build_settings('Debug')["ARCHS"].should == "armv6 armv7"
        target.build_settings('Release')["ARCHS"].should == "armv6 armv7"
      end

      it "uses standard ARCHs if deployment target is 4.3 or above" do
        @installer.install!
        target = @project.targets.first
        target.build_settings('Debug')["ARCHS"].should == "$(ARCHS_STANDARD_32_BIT)"
        target.build_settings('AppStore')["ARCHS"].should == "$(ARCHS_STANDARD_32_BIT)"
      end

      it "sets VALIDATE_PRODUCT to YES for the Release configuration for iOS targets" do
        @installer.install!
        target = @project.targets.first
        target.build_settings('Release')["VALIDATE_PRODUCT"].should == "YES"
      end

      it "sets IPHONEOS_DEPLOYMENT_TARGET for iOS targets" do
        @installer.install!
        target = @project.targets.first
        target.build_settings('Debug')["IPHONEOS_DEPLOYMENT_TARGET"].should == "6.0"
        target.build_settings('AppStore')["IPHONEOS_DEPLOYMENT_TARGET"].should == "6.0"
      end

      it "sets MACOSX_DEPLOYMENT_TARGET for OS X targets" do
        @library.platform = Platform.new(:osx, '10.8')
        @installer.install!
        target = @project.targets.first
        target.build_settings('Debug')["MACOSX_DEPLOYMENT_TARGET"].should == "10.8"
        target.build_settings('AppStore')["MACOSX_DEPLOYMENT_TARGET"].should == "10.8"
      end

      it "adds the settings of the xcconfig that need to be overridden to the target" do
        @installer.install!
        build_configuration = @project.targets.first.build_configurations
        build_settings      = build_configuration.first.build_settings
        Generator::XCConfig.pods_project_settings.each do |key, value|
          build_settings[key].should == value
        end
      end

      it "adds the user's build configurations to the target" do
        @installer.install!
        @project.targets.first.build_configurations.map(&:name).sort.should == %w{ AppStore Debug Release Test }
      end

      it "does not enable the GCC_WARN_INHIBIT_ALL_WARNINGS flag by default" do
        @installer.install!
        @installer.target.build_configurations.each do |config|
          config.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'].should.be.nil
        end
      end

      it "enables the GCC_WARN_INHIBIT_ALL_WARNINGS flag" do
        @podfile.inhibit_all_warnings!
        @installer.install!
        @installer.target.build_configurations.each do |config|
          config.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'].should == 'YES'
        end
      end

      #--------------------------------------#

      it 'adds the source files of each pod to the target of the Pod library' do
        @installer.install!
        names = @installer.target.source_build_phase.files.map { |bf| bf.file_ref.name }
        names.should.include("Banana.m")
      end

      it 'adds the frameworks required by to the pod to the project for informative purposes' do
        Specification.any_instance.stubs(:frameworks).returns(['QuartzCore'])
        @installer.install!
        names = @installer.project['Frameworks'].children.map(&:name)
        names.sort.should == ["Foundation.framework", "QuartzCore.framework"]
      end

      #--------------------------------------#

      it "creates and xcconfig file" do
        @installer.install!
        file = config.sandbox.root + 'Pods.xcconfig'
        xcconfig = Xcodeproj::Config.new(file)
        xcconfig.to_hash['PODS_ROOT'].should == '${SRCROOT}/Pods'
      end

      it "creates a prefix header, including the contents of the specification's prefix header" do
        @pod.top_specification.prefix_header_contents = '#import "BlocksKit.h"'
        @installer.install!
        prefix_header = config.sandbox.root + 'Pods-prefix.pch'
        prefix_header.read.should == <<-EOS.strip_heredoc
          #ifdef __OBJC__
          #import <UIKit/UIKit.h>
          #endif

          #import "BlocksKit.h"
        EOS
      end

      it "creates a bridge support file" do
        Podfile.any_instance.stubs(:generate_bridge_support? => true)
        Generator::BridgeSupport.any_instance.expects(:save_as).once
        @installer.install!
      end

      it "creates a create copy resources script" do
        @installer.install!
        script = config.sandbox.root + 'Pods-resources.sh'
        script.read.should.include?('logo-sidebar.png')
      end

      it "creates the acknowledgements files " do
        @installer.install!
        markdown = config.sandbox.root + 'Pods-Acknowledgements.markdown'
        markdown.read.should.include?('Permission is hereby granted')
        plist = config.sandbox.root + 'Pods-Acknowledgements.plist'
        plist.read.should.include?('Permission is hereby granted')
      end

      it "creates a dummy source to ensure the compilation of libraries with only categories" do
        @installer.install!
        build_files = @installer.target.source_build_phase.files
        build_file = build_files.find { |bf| bf.file_ref.name == 'Pods-Dummy.m' }
        build_file.should.be.not.nil
        build_file.file_ref.path.should == 'Pods-Dummy.m'
        dummy = config.sandbox.root + 'Pods-Dummy.m'
        dummy.read.should.include?('@interface PodsDummy_Pods')
      end
    end
  end
end
