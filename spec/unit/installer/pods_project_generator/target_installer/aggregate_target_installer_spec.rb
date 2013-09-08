require File.expand_path('../../../../../spec_helper', __FILE__)

module Pod
  describe Installer::PodsProjectGenerator::AggregateTargetInstaller do
    describe "In General" do
      before do
        config.sandbox.project = Project.new(config.sandbox.project_path)

        @target = AggregateTarget.new(@target_definition, config.sandbox)
        @target.stubs(:label).returns('Pods')
        @target.stubs(:platform).returns(Platform.new(:ios, '6.0'))
        @target.user_build_configurations = { 'AppStore' => :release, 'Test' => :debug }

        @sut = Installer::PodsProjectGenerator::AggregateTargetInstaller.new(config.sandbox, @target)
      end

      #-----------------------------------------------------------------------#

      it 'adds the target for the static target to the project' do
        @sut.generate!
        config.sandbox.project.targets.count.should == 1
        config.sandbox.project.targets.first.name.should == 'Pods'
      end

      it "adds the user build configurations to the target" do
        @sut.generate!
        target = config.sandbox.project.targets.first
        target.build_settings('Test')["VALIDATE_PRODUCT"].should == nil
        target.build_settings('AppStore')["VALIDATE_PRODUCT"].should == "YES"
      end

      it "sets VALIDATE_PRODUCT to YES for the Release configuration for iOS targets" do
        @sut.generate!
        target = config.sandbox.project.targets.first
        target.build_settings('Release')["VALIDATE_PRODUCT"].should == "YES"
      end

      it "sets the platform and the deployment target for iOS targets" do
        @sut.generate!
        target = config.sandbox.project.targets.first
        target.platform_name.should == :ios
        target.deployment_target.should == "6.0"
        target.build_settings('Debug')["IPHONEOS_DEPLOYMENT_TARGET"].should == "6.0"
        target.build_settings('AppStore')["IPHONEOS_DEPLOYMENT_TARGET"].should == "6.0"
      end

      it "sets the platform and the deployment target for OS X targets" do
        @target.stubs(:platform).returns(Platform.new(:osx, '10.8'))
        @sut.generate!
        target = config.sandbox.project.targets.first
        target.platform_name.should == :osx
        target.deployment_target.should == "10.8"
        target.build_settings('Debug')["MACOSX_DEPLOYMENT_TARGET"].should == "10.8"
        target.build_settings('AppStore')["MACOSX_DEPLOYMENT_TARGET"].should == "10.8"
      end

      it "adds the user's build configurations to the target" do
        @sut.generate!
        config.sandbox.project.targets.first.build_configurations.map(&:name).sort.should == %w{ AppStore Debug Release Test }
      end

      it "it creates different hash instances for the build settings of various build configurations" do
        @sut.generate!
        build_settings = config.sandbox.project.targets.first.build_configurations.map(&:build_settings)
        build_settings.map(&:object_id).uniq.count.should == 4
      end

      it "does not enable the GCC_WARN_INHIBIT_ALL_WARNINGS flag by default" do
        @sut.generate!
        @sut.target.target.build_configurations.each do |config|
          config.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'].should.be.nil
        end
      end

      #-----------------------------------------------------------------------#

      it "adds file references for the support files of the target" do
        @sut.generate!
        @project.support_files_group
        group = @project['Pods/BananaLib/Support Files']
        group.children.map(&:display_name).sort.should == [
          "Pods-BananaLib-Private.xcconfig",
          "Pods-BananaLib-dummy.m",
          "Pods-BananaLib-prefix.pch",
          "Pods-BananaLib.xcconfig",
        ]
      end

      it "creates the xcconfig file" do
        @sut.generate!
        file = config.sandbox.root + @pod_target.xcconfig_private_path
        xcconfig = Xcodeproj::Config.new(file)
        xcconfig.to_hash['PODS_ROOT'].should == '${SRCROOT}'
      end

      it "creates a prefix header, including the contents of the specification's prefix header" do
        @spec.prefix_header_contents = '#import "BlocksKit.h"'
        @sut.generate!
        prefix_header = config.sandbox.root + 'Pods-BananaLib-prefix.pch'
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
  end
end
