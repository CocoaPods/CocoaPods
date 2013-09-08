require File.expand_path('../../../../../spec_helper', __FILE__)

module Pod
  describe Installer::PodsProjectGenerator::PodTargetInstaller do
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
        @project.add_pod_group('BananaLib', fixture('banana-lib'))
        group = @project.group_for_spec('BananaLib', :source_files)
        file_accessor.source_files.each do |file|
          @project.add_file_reference(file, group)
        end

        @pod_target = PodTarget.new([@spec], @target_definition, config.sandbox)
        @pod_target.stubs(:platform).returns(Platform.new(:ios, '6.0'))
        @pod_target.file_accessors = [file_accessor]
        @pod_target.user_build_configurations = { 'Debug' => :debug, 'Release' => :release }
        @installer = Installer::PodsProjectGenerator::PodTargetInstaller.new(config.sandbox, @pod_target)

        @spec.prefix_header_contents = '#import "BlocksKit.h"'
      end

      #--------------------------------------#

      it 'adds the target for the static target to the project' do
        @installer.install!
        @project.targets.count.should == 1
        @project.targets.first.name.should == 'Pods-BananaLib' 
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
      end

      it "sets the platform and the deployment target for OS X targets" do
        @pod_target.stubs(:platform).returns(Platform.new(:osx, '10.8'))
        @installer.install!
        target = @project.targets.first
        target.platform_name.should == :osx
        target.deployment_target.should == "10.8"
        target.build_settings('Debug')["MACOSX_DEPLOYMENT_TARGET"].should == "10.8"
      end

      it "adds the user's build configurations to the target" do
        @pod_target.user_build_configurations.merge!({ 'AppStore' => :release, 'Test' => :debug })
        @installer.install!
        @project.targets.first.build_configurations.map(&:name).sort.should == %w{ AppStore Debug Release Test }
      end

      it "it creates different hash instances for the build settings of various build configurations" do
        @installer.install!
        build_settings = @project.targets.first.build_configurations.map(&:build_settings)
        build_settings.map(&:object_id).uniq.count.should == 2
      end

      it "does not enable the GCC_WARN_INHIBIT_ALL_WARNINGS flag by default" do
        @installer.install!
        @installer.target.target.build_configurations.each do |config|
          config.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'].should.be.nil
        end
      end

      #--------------------------------------#

      it 'adds the source files of each pod to the target of the Pod target' do
        @installer.install!
        names = @installer.target.target.source_build_phase.files.map { |bf| bf.file_ref.display_name }
        names.should.include("Banana.m")
      end

      #--------------------------------------#

      xit 'adds the resource bundle targets' do

      end

      xit 'adds the build configurations to the resources bundle targets' do

      end

      #--------------------------------------#

      xit 'links to system frameworks' do

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
          @installer.target.target_definition.stubs(:inhibits_warnings_for_pod?).returns(true)
          flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios))

          flags.should.include?('-w')
        end

        it "doesn't inhibit warnings by default" do
          flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios))
          flags.should.not.include?('-w')
        end

        it "adds -Xanalyzer -analyzer-disable-checker per pod" do
          @installer.target.target_definition.stubs(:inhibits_warnings_for_pod?).returns(true)
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
