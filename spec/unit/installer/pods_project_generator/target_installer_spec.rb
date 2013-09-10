require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Installer::PodsProjectGenerator::TargetInstaller do

    describe "#install!" do
      xit 'adds the target for the static target to the project' do
        @sut.send(:add_target)
        @project.targets.count.should == 1
        @project.targets.first.name.should == 'Pods'
      end
    end

    #-------------------------------------------------------------------------#

    describe "#add_target" do

      before do
        @project = Project.new(config.sandbox.project_path)
        target = AggregateTarget.new(nil, config.sandbox)
        target.stubs(:label).returns('Pods')
        target.stubs(:platform).returns(Platform.new(:ios, '6.0'))
        @sut = Installer::PodsProjectGenerator::TargetInstaller.new(@project, target)
      end

      it 'adds the target for the static target to the project' do
        @sut.send(:add_target)
        @project.targets.count.should == 1
        @project.targets.first.name.should == 'Pods'
      end

      it "sets the ARCHS" do
        @sut.send(:add_target)
        target = @project.targets.first
        target.build_settings('Debug')["ARCHS"].should == "$(ARCHS_STANDARD_32_BIT)"
        target.build_settings('Debug')["ONLY_ACTIVE_ARCH"].should.be.nil
      end

      it "sets ARCHS to 'armv6 armv7' for both configurations if the deployment target is less than 4.3 for iOS targets" do
        @sut.target.stubs(:platform).returns(Platform.new(:ios, '4.0'))
        @sut.send(:add_target)
        target = @project.targets.first
        target.build_settings('Debug')["ARCHS"].should == "armv6 armv7"
        target.build_settings('Release')["ARCHS"].should == "armv6 armv7"
      end

      it "sets VALIDATE_PRODUCT to YES for the Release configuration for iOS targets" do
        @sut.send(:add_target)
        target = @project.targets.first
        target.build_settings('Release')["VALIDATE_PRODUCT"].should == "YES"
      end


      it "sets the platform and the deployment target for iOS targets" do
        @sut.install!
        target = @project.targets.first
        target.platform_name.should == :ios
        target.deployment_target.should == "6.0"
        target.build_settings('Debug')["IPHONEOS_DEPLOYMENT_TARGET"].should == "6.0"
      end

      it "sets the platform and the deployment target for OS X targets" do
        @sut.target.stubs(:platform).returns(Platform.new(:osx, '10.8'))
        @sut.install!
        target = @project.targets.first
        target.platform_name.should == :osx
        target.deployment_target.should == "10.8"
        target.build_settings('Debug')["MACOSX_DEPLOYMENT_TARGET"].should == "10.8"
      end

      it "adds the user's build configurations to the target" do
        @sut.target.user_build_configurations = { 'AppStore' => :release, 'Test' => :debug }
        @sut.send(:add_target)
        @project.targets.first.build_configurations.map(&:name).sort.should == %w{ AppStore Debug Release Test }
      end

      it "it creates different hash instances for the build settings of various build configurations" do
        @sut.send(:add_target)
        build_settings = @project.targets.first.build_configurations.map(&:build_settings)
        build_settings.map(&:object_id).uniq.count.should == 2
      end

      it "does not enable the GCC_WARN_INHIBIT_ALL_WARNINGS flag by default" do
        @sut.send(:add_target)
        @sut.target.native_target.build_configurations.each do |config|
          config.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'].should.be.nil
        end
      end
    end

    #-------------------------------------------------------------------------#

    describe "In General" do
      before do
        project = Project.new(config.sandbox.project_path)
        spec = fixture_spec('banana-lib/BananaLib.podspec')
        file_accessor = fixture_file_accessor('banana-lib/BananaLib.podspec')
        project.add_pod_group('BananaLib', fixture('banana-lib'))
        group = project.group_for_spec('BananaLib', :source_files)
        file_accessor.source_files.each do |file|
          project.add_file_reference(file, group)
        end

        target = PodTarget.new([spec], nil, config.sandbox)
        target.stubs(:platform).returns(Platform.new(:ios, '6.0'))
        target.file_accessors = [file_accessor]
        target.stubs(:inhibits_warnings?).returns(false)
        target.stubs(:label).returns('Pods-BananaLib')
        @sut = Installer::PodsProjectGenerator::TargetInstaller.new(project, target)
        @sut.send(:add_target)
      end

      it 'adds the source files of each pod to the target of the Pod target' do
        @sut.send(:add_files_to_build_phases)
        source_files = @sut.target.native_target.source_build_phase.files_references
        source_files.map { |ref| ref.display_name }.should == ['Banana.m']
      end

      it 'sets the compiler flags of the source files' do
        compiler_flag = '-flag'
        Specification::Consumer.any_instance.stubs(:compiler_flags).returns([compiler_flag])
        @sut.send(:add_files_to_build_phases)
        build_files = @sut.target.native_target.source_build_phase.files
        build_files.first.settings.should == { 'COMPILER_FLAGS' => compiler_flag }
      end
    end

    #-------------------------------------------------------------------------#

    describe "#add_resources_bundle_targets" do

      xit 'adds the resource bundle targets' do

      end

      xit 'adds the build configurations to the resources bundle targets' do

      end

    end

    #-------------------------------------------------------------------------#

    describe "#link_to_system_frameworks" do
      before do
        project = Project.new(config.sandbox.project_path)
        target = PodTarget.new([], nil, config.sandbox)
        target.stubs(:platform).returns(Platform.new(:ios, '6.0'))
        target.stubs(:label).returns('Pods-BananaLib')
        @sut = Installer::PodsProjectGenerator::TargetInstaller.new(project, target)
        @sut.send(:add_target)
      end

      it 'links to system frameworks' do
        @sut.target.stubs(:frameworks).returns(['QuartzCore', 'QuartzCore'])
        @sut.send(:link_to_system_frameworks)
        build_files = @sut.target.native_target.frameworks_build_phase.files
        build_files = @sut.target.native_target.frameworks_build_phase.file_display_names
        build_files.should == ["Foundation.framework", "QuartzCore.framework"]
      end

      it 'links to system libraries' do
        @sut.target.stubs(:libraries).returns(['z', 'xml2'])
        @sut.send(:link_to_system_frameworks)
        build_files = @sut.target.native_target.frameworks_build_phase.file_display_names
        build_files.should == ["Foundation.framework", "libz.dylib", "libxml2.dylib"]
      end

    end

    #-----------------------------------------------------------------------#

    describe "#compiler_flags_for_consumer" do

      before do
        @spec = Pod::Spec.new
        @sut = Installer::PodsProjectGenerator::TargetInstaller.new(nil, nil)
      end

      it "does not do anything if ARC is *not* required" do
        @spec.requires_arc = false
        @spec.ios.deployment_target = '5'
        @spec.osx.deployment_target = '10.6'
        ios_flags = @sut.send(:compiler_flags_for_consumer, @spec.consumer(:ios))
        osx_flags = @sut.send(:compiler_flags_for_consumer, @spec.consumer(:osx))
        ios_flags.should.not.include '-DOS_OBJECT_USE_OBJC'
        osx_flags.should.not.include '-DOS_OBJECT_USE_OBJC'
      end

      it "does *not* disable the `OS_OBJECT_USE_OBJC` flag if ARC is required and has a deployment target of >= iOS 6.0 or OS X 10.8" do
        @spec.requires_arc = false
        @spec.ios.deployment_target = '6'
        @spec.osx.deployment_target = '10.8'
        ios_flags = @sut.send(:compiler_flags_for_consumer, @spec.consumer(:ios))
        osx_flags = @sut.send(:compiler_flags_for_consumer, @spec.consumer(:osx))
        ios_flags.should.not.include '-DOS_OBJECT_USE_OBJC'
        osx_flags.should.not.include '-DOS_OBJECT_USE_OBJC'
      end

      it "*does* disable the `OS_OBJECT_USE_OBJC` flag if ARC is required but has a deployment target < iOS 6.0 or OS X 10.8" do
        @spec.requires_arc = true
        @spec.ios.deployment_target = '5.1'
        @spec.osx.deployment_target = '10.7.2'
        ios_flags = @sut.send(:compiler_flags_for_consumer, @spec.consumer(:ios))
        osx_flags = @sut.send(:compiler_flags_for_consumer, @spec.consumer(:osx))
        ios_flags.should.include '-DOS_OBJECT_USE_OBJC'
        osx_flags.should.include '-DOS_OBJECT_USE_OBJC'
      end

      it "*does* disable the `OS_OBJECT_USE_OBJC` flag if ARC is required and *no* deployment target is specified" do
        @spec.requires_arc = true
        ios_flags = @sut.send(:compiler_flags_for_consumer, @spec.consumer(:ios))
        osx_flags = @sut.send(:compiler_flags_for_consumer, @spec.consumer(:osx))
        ios_flags.should.include '-DOS_OBJECT_USE_OBJC'
        osx_flags.should.include '-DOS_OBJECT_USE_OBJC'
      end

      it "adds -w per pod if target definition inhibits warnings for that pod" do
        flags = @sut.send(:compiler_flags_for_consumer, @spec.consumer(:ios), true)
        flags.should.include?('-w')
        flags.should.include?('-Xanalyzer -analyzer-disable-checker')
      end

      it "doesn't inhibit warnings by default" do
        flags = @sut.send(:compiler_flags_for_consumer, @spec.consumer(:ios), false)
        flags.should.not.include?('-w')
        flags.should.not.include?('-Xanalyzer -analyzer-disable-checker')
      end
    end

    #-----------------------------------------------------------------------#

  end
end
