require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Installer::PodsProjectGenerator::SupportFilesGenerator do

    describe "AggregateTarget" do
      before do
        @project = Project.new(config.sandbox.project_path)
        native_target = @project.new_target(:static_target, 'Pods', :ios, '6.0')

        @podfile = Podfile.new do
          platform :ios
          xcodeproj 'dummy'
        end
        @target_definition = @podfile.target_definitions['Pods']
        @target = AggregateTarget.new(@target_definition, config.sandbox)
        @target.stubs(:label).returns('Pods')
        @target.stubs(:platform).returns(Platform.new(:ios, '6.0'))
        @target.user_project_path = config.sandbox.root + '../user_project.xcodeproj'
        @target.client_root = config.sandbox.root.dirname
        @target.user_build_configurations = { 'Debug' => :debug, 'Release' => :release, 'AppStore' => :release, 'Test' => :debug }
        @target.target = native_target

        file_accessor = fixture_file_accessor('banana-lib/BananaLib.podspec')
        @spec = fixture_spec('banana-lib/BananaLib.podspec')
        @pod_target = PodTarget.new([@spec], @target_definition, config.sandbox)
        @pod_target.stubs(:platform).returns(Platform.new(:ios, '6.0'))
        @pod_target.user_build_configurations = @target.user_build_configurations
        @pod_target.file_accessors = [file_accessor]

        @target.pod_targets = [@pod_target]

        @sut = Installer::PodsProjectGenerator::SupportFilesGenerator.new(@target, @project)
      end

      it "adds file references for the support files of the target" do
        @sut.generate!
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


      it "creates the xcconfig file" do
        @sut.generate!
        file = config.sandbox.root + @target.xcconfig_path
        xcconfig = Xcodeproj::Config.new(file)
        xcconfig.to_hash['PODS_ROOT'].should == '${SRCROOT}/Pods'
      end

      it "creates a header for the target which contains the information about the installed Pods" do
        @sut.generate!
        file = config.sandbox.root + 'Pods-environment.h'
        contents = file.read
        contents.should.include?('#define COCOAPODS_POD_AVAILABLE_BananaLib')
        contents.should.include?('#define COCOAPODS_VERSION_MAJOR_BananaLib 1')
        contents.should.include?('#define COCOAPODS_VERSION_MINOR_BananaLib 0')
        contents.should.include?('#define COCOAPODS_VERSION_PATCH_BananaLib 0')
      end

      it "creates a bridge support file" do
        Podfile.any_instance.stubs(:generate_bridge_support? => true)
        Generator::BridgeSupport.any_instance.expects(:save_as).once
        @sut.generate!
      end

      it "creates a create copy resources script" do
        @sut.generate!
        script = config.sandbox.root + 'Pods-resources.sh'
        script.read.should.include?('logo-sidebar.png')
      end

      xit "adds the resources bundles to the copy resources script" do

      end

      xit "adds the bridge support file to the copy resources script, if one was created" do

      end

      it "creates the acknowledgements files " do
        @sut.generate!
        markdown = config.sandbox.root + 'Pods-acknowledgements.markdown'
        markdown.read.should.include?('Permission is hereby granted')
        plist = config.sandbox.root + 'Pods-acknowledgements.plist'
        plist.read.should.include?('Permission is hereby granted')
      end

      it "creates a dummy source to ensure the creation of a single base target" do
        @sut.generate!
        build_files = @sut.target.target.source_build_phase.files
        build_file = build_files.find { |bf| bf.file_ref.path.include?('Pods-dummy.m') }
        build_file.should.be.not.nil
        build_file.file_ref.path.should == 'Pods-dummy.m'
        dummy = config.sandbox.root + 'Pods-dummy.m'
        dummy.read.should.include?('@interface PodsDummy_Pods')
      end

    end

    #-------------------------------------------------------------------------#

    describe "PodTarget" do
      before do
        @project = Project.new(config.sandbox.project_path)
        @project.add_pod_group('BananaLib', fixture('banana-lib'))
        native_target = @project.new_target(:static_target, 'Pods-BananaLib', :ios, '6.0')

        @podfile = Podfile.new do
          platform :ios
          xcodeproj 'dummy'
        end
        @target_definition = @podfile.target_definitions['Pods']

        file_accessor = fixture_file_accessor('banana-lib/BananaLib.podspec')
        @spec = fixture_spec('banana-lib/BananaLib.podspec')
        @target = PodTarget.new([@spec], @target_definition, config.sandbox)
        @target.stubs(:platform).returns(Platform.new(:ios, '6.0'))
        @target.user_build_configurations = @target.user_build_configurations
        @target.file_accessors = [file_accessor]
        @target.target = native_target

        @sut = Installer::PodsProjectGenerator::SupportFilesGenerator.new(@target, @project)
      end

      it "creates the xcconfig file" do
        @sut.generate!
        file = config.sandbox.root + @target.xcconfig_private_path
        xcconfig = Xcodeproj::Config.new(file)
        xcconfig.to_hash['PODS_ROOT'].should == '${SRCROOT}'
      end

      it "creates a prefix header, including the contents of the specification's prefix header" do
        @sut.generate!
        prefix_header = config.sandbox.root + 'Pods-BananaLib-prefix.pch'
        generated = prefix_header.read
        expected = <<-EOS.strip_heredoc
          #ifdef __OBJC__
          #import <UIKit/UIKit.h>
          #endif

          #import "Pods-environment.h"
          #import <BananaTree/BananaTree.h>
        EOS
        generated.should == expected
      end

      it "creates a dummy source to ensure the compilation of libraries with only categories" do
        @sut.generate!
        build_files = @sut.target.target.source_build_phase.files
        build_file = build_files.find { |bf| bf.file_ref.display_name == 'Pods-BananaLib-dummy.m' }
        build_file.should.be.not.nil
        build_file.file_ref.path.should == 'Pods-BananaLib-dummy.m'
        dummy = config.sandbox.root + 'Pods-BananaLib-dummy.m'
        dummy.read.should.include?('@interface PodsDummy_Pods')
      end
    end


    #-------------------------------------------------------------------------#

  end
end
