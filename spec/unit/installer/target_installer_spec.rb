require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe TargetInstaller = Installer::TargetInstaller do

    describe "In General" do

      before do
        @podfile = Podfile.new do
          platform :ios
          xcodeproj 'dummy'
        end
        @target_definition = @podfile.target_definitions['Pods']
        @project = Project.new(config.sandbox.project_path)

        config.sandbox.project = @project
        path_list = Sandbox::PathList.new(fixture('banana-lib'))
        @spec = fixture_spec('banana-lib/BananaLib.podspec')
        file_accessor = Sandbox::FileAccessor.new(path_list, @spec.consumer(:ios))
        @project.add_file_references(file_accessor.source_files, 'BananaLib', @project.pods)

        @library = Target.new(@target_definition, config.sandbox)
        @library.platform = Platform.new(:ios, '6.0')
        @library.support_files_root = config.sandbox.root
        @library.client_root = config.sandbox.root.dirname
        @library.user_project_path = config.sandbox.root + '../user_project.xcodeproj'
        @library.user_build_configurations = { 'Debug' => :debug, 'Release' => :release, 'AppStore' => :release, 'Test' => :debug }
        @library.spec = @spec
        @library.file_accessors = [file_accessor]

        @installer = TargetInstaller.new(config.sandbox, @library)

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

      it "sets the platform and the deployment target for iOS targets" do
        @installer.install!
        target = @project.targets.first
        target.platform_name.should == :ios
        target.deployment_target.should == "6.0"
        target.build_settings('Debug')["IPHONEOS_DEPLOYMENT_TARGET"].should == "6.0"
        target.build_settings('AppStore')["IPHONEOS_DEPLOYMENT_TARGET"].should == "6.0"
      end

      it "sets the platform and the deployment target for OS X targets" do
        @library.platform = Platform.new(:osx, '10.8')
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

      it 'adds the source files of each pod to the target of the Pod library' do
        @installer.install!
        names = @installer.library.target.source_build_phase.files.map { |bf| bf.file_ref.name }
        names.should.include("Banana.m")
      end

      it 'adds the frameworks required by to the pod to the project for informative purposes' do
        Specification::Consumer.any_instance.stubs(:frameworks).returns(['QuartzCore'])
        @installer.install!
        names = @installer.sandbox.project['Frameworks'].children.map(&:name)
        names.sort.should == ["Foundation.framework", "QuartzCore.framework"]
      end

      #--------------------------------------#

      it "creates the xcconfig file" do
        @installer.install!
        file = config.sandbox.root + @library.xcconfig_path
        xcconfig = Xcodeproj::Config.new(file)
        xcconfig.to_hash['PODS_ROOT'].should == '${SRCROOT}'
      end

      it "creates a header for the target which contains the information about the installed Pods" do
        target = Target.new(@target_definition, config.sandbox)
        lib_definition = Podfile::TargetDefinition.from_hash(@target_definition.to_hash, @target_definition.parent)
        lib_definition.name = 'BananaLib'
        library = Target.new(@target_definition, config.sandbox)

        target.platform           = library.platform           = @library.platform
        target.support_files_root = library.support_files_root = @library.support_files_root
        target.client_root        = library.client_root        = @library.client_root
        target.user_project_path  = library.user_project_path  = @library.user_project_path
        target.user_build_configurations = library.user_build_configurations = @library.user_build_configurations
        library.spec = @library.spec
        library.file_accessors = @library.file_accessors
        target.libraries = [library]

        @installer = TargetInstaller.new(config.sandbox, target)
        @installer.install!
        file = config.sandbox.root + 'Pods-environment.h'
        contents = file.read
        contents.should.include?('#define COCOAPODS_POD_AVAILABLE_BananaLib')
        contents.should.include?('#define COCOAPODS_VERSION_MAJOR_BananaLib 1')
        contents.should.include?('#define COCOAPODS_VERSION_MINOR_BananaLib 0')
        contents.should.include?('#define COCOAPODS_VERSION_PATCH_BananaLib 0')
      end

      it "creates a prefix header, including the contents of the specification's prefix header" do
        @spec.prefix_header_contents = '#import "BlocksKit.h"'
        @installer.install!
        prefix_header = config.sandbox.root + 'Pods-prefix.pch'
        generated = prefix_header.read
        expected = <<-EOS.strip_heredoc
          #ifdef __OBJC__
          #import <UIKit/UIKit.h>
          #endif

          #import "Pods-environment.h"
          #import "BlocksKit.h"
          #import <BananaTree/BananaTree.h>
        EOS
        generated.should == expected
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
        markdown = config.sandbox.root + 'Pods-acknowledgements.markdown'
        markdown.read.should.include?('Permission is hereby granted')
        plist = config.sandbox.root + 'Pods-acknowledgements.plist'
        plist.read.should.include?('Permission is hereby granted')
      end

      it "creates a dummy source to ensure the compilation of libraries with only categories" do
        @installer.install!
        build_files = @installer.library.target.source_build_phase.files
        build_file = build_files.find { |bf| bf.file_ref.name == 'Pods-dummy.m' }
        build_file.should.be.not.nil
        build_file.file_ref.path.should == 'Pods-dummy.m'
        dummy = config.sandbox.root + 'Pods-dummy.m'
        dummy.read.should.include?('@interface PodsDummy_Pods')
      end

      #--------------------------------------------------------------------------------#

      describe "concerning ARC before and after iOS 6.0 and OS X 10.8" do
        before do
          @spec = Pod::Spec.new
        end

        it "does not do anything if ARC is *not* required" do
          @spec.requires_arc = false
          @spec.ios.deployment_target = '5'
          @spec.osx.deployment_target = '10.6'
          ios_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios))
          osx_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:osx))
          ios_flags.should.not.include '-DOS_OBJECT_USE_OBJC'
          osx_flags.should.not.include '-DOS_OBJECT_USE_OBJC'
        end

        it "does *not* disable the `OS_OBJECT_USE_OBJC` flag if ARC is required and has a deployment target of >= iOS 6.0 or OS X 10.8" do
          @spec.requires_arc = false
          @spec.ios.deployment_target = '6'
          @spec.osx.deployment_target = '10.8'
          ios_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios))
          osx_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:osx))
          ios_flags.should.not.include '-DOS_OBJECT_USE_OBJC'
          osx_flags.should.not.include '-DOS_OBJECT_USE_OBJC'
        end

        it "*does* disable the `OS_OBJECT_USE_OBJC` flag if ARC is required but has a deployment target < iOS 6.0 or OS X 10.8" do
          @spec.requires_arc = true
          @spec.ios.deployment_target = '5.1'
          @spec.osx.deployment_target = '10.7.2'
          ios_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios))
          osx_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:osx))
          ios_flags.should.include '-DOS_OBJECT_USE_OBJC'
          osx_flags.should.include '-DOS_OBJECT_USE_OBJC'
        end

        it "*does* disable the `OS_OBJECT_USE_OBJC` flag if ARC is required and *no* deployment target is specified" do
          @spec.requires_arc = true
          ios_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios))
          osx_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:osx))
          ios_flags.should.include '-DOS_OBJECT_USE_OBJC'
          osx_flags.should.include '-DOS_OBJECT_USE_OBJC'
        end

        it "adds -w per pod if target definition inhibits warnings for that pod" do
          @installer.library.target_definition.stubs(:inhibits_warnings_for_pod?).returns(true)
          flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios))

          flags.should.include?('-w')
        end

        it "doesn't inhibit warnings by default" do
          flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios))
          flags.should.not.include?('-w')
        end

        it "adds -Xanalyzer -analyzer-disable-checker per pod" do
          @installer.library.target_definition.stubs(:inhibits_warnings_for_pod?).returns(true)
          flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios))

          flags.should.include?('-Xanalyzer -analyzer-disable-checker')
        end

        it "doesn't inhibit analyzer warnings by default" do
          flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios))
          flags.should.not.include?('-Xanalyzer -analyzer-disable-checker')
        end

      end
    end
  end
end
