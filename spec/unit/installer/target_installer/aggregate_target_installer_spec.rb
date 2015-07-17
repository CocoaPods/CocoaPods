require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Installer::AggregateTargetInstaller do
    describe 'In General' do
      before do
        config.sandbox.prepare
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
        group = @project.group_for_spec('BananaLib')
        file_accessor.source_files.each do |file|
          @project.add_file_reference(file, group)
        end

        @target = AggregateTarget.new(@target_definition, config.sandbox)
        @target.stubs(:platform).returns(Platform.new(:ios, '6.0'))
        @target.user_project_path = config.sandbox.root + '../user_project.xcodeproj'
        @target.client_root = config.sandbox.root.dirname
        @target.user_build_configurations = { 'Debug' => :debug, 'Release' => :release, 'AppStore' => :release, 'Test' => :debug }

        @pod_target = PodTarget.new([@spec], [@target_definition], config.sandbox)
        @pod_target.stubs(:platform).returns(Platform.new(:ios, '6.0'))
        @pod_target.user_build_configurations = @target.user_build_configurations
        @pod_target.file_accessors = [file_accessor]

        @target.pod_targets = [@pod_target]

        @installer = Installer::AggregateTargetInstaller.new(config.sandbox, @target)

        @spec.prefix_header_contents = '#import "BlocksKit.h"'
      end

      it 'adds file references for the support files of the target' do
        @installer.install!
        group = @project.support_files_group['Pods']
        group.children.map(&:display_name).sort.should == [
          'Pods-acknowledgements.markdown',
          'Pods-acknowledgements.plist',
          'Pods-dummy.m',
          'Pods-frameworks.sh',
          'Pods-resources.sh',
          'Pods.appstore.xcconfig',
          'Pods.debug.xcconfig',
          'Pods.release.xcconfig',
          'Pods.test.xcconfig',
        ]
      end

      #--------------------------------------#

      it 'adds the target for the static library to the project' do
        @installer.install!
        @project.targets.count.should == 1
        @project.targets.first.name.should == @target_definition.label
      end

      it 'sets the platform and the deployment target for iOS targets' do
        @installer.install!
        target = @project.targets.first
        target.platform_name.should == :ios
        target.deployment_target.should == '6.0'
        target.build_settings('Debug')['IPHONEOS_DEPLOYMENT_TARGET'].should == '6.0'
        target.build_settings('AppStore')['IPHONEOS_DEPLOYMENT_TARGET'].should == '6.0'
      end

      it 'sets the platform and the deployment target for OS X targets' do
        @target.stubs(:platform).returns(Platform.new(:osx, '10.8'))
        @installer.install!
        target = @project.targets.first
        target.platform_name.should == :osx
        target.deployment_target.should == '10.8'
        target.build_settings('Debug')['MACOSX_DEPLOYMENT_TARGET'].should == '10.8'
        target.build_settings('AppStore')['MACOSX_DEPLOYMENT_TARGET'].should == '10.8'
      end

      it "adds the user's build configurations to the target" do
        @installer.install!
        @project.targets.first.build_configurations.map(&:name).sort.should == %w(        AppStore Debug Release Test        )
      end

      it 'it creates different hash instances for the build settings of various build configurations' do
        @installer.install!
        build_settings = @project.targets.first.build_configurations.map(&:build_settings)
        build_settings.map(&:object_id).uniq.count.should == 4
      end

      it 'does not enable the GCC_WARN_INHIBIT_ALL_WARNINGS flag by default' do
        @installer.install!
        @installer.target.native_target.build_configurations.each do |config|
          config.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'].should.be.nil
        end
      end

      it 'will be skipped when installing' do
        @installer.install!
        @installer.target.native_target.build_configurations.each do |config|
          config.build_settings['SKIP_INSTALL'].should == 'YES'
        end
      end

      #--------------------------------------#

      it 'creates the xcconfig file' do
        @installer.install!
        file = config.sandbox.root + @target.xcconfig_path('Release')
        xcconfig = Xcodeproj::Config.new(file)
        xcconfig.to_hash['PODS_ROOT'].should == '${SRCROOT}/Pods'
      end

      it 'creates a bridge support file' do
        Podfile.any_instance.stubs(:generate_bridge_support? => true)
        Generator::BridgeSupport.any_instance.expects(:save_as).once
        @installer.install!
      end

      it 'creates a create copy resources script' do
        @installer.install!
        support_files_dir = config.sandbox.target_support_files_dir('Pods')
        script = support_files_dir + 'Pods-resources.sh'
        script.read.should.include?('logo-sidebar.png')
      end

      it 'does not add framework resources to copy resources script' do
        @pod_target.stubs(:requires_frameworks? => true)
        @installer.install!
        support_files_dir = config.sandbox.target_support_files_dir('Pods')
        script = support_files_dir + 'Pods-resources.sh'
        script.read.should.not.include?('logo-sidebar.png')
      end

      xit 'adds the resources bundles to the copy resources script' do
      end

      xit 'adds the bridge support file to the copy resources script, if one was created' do
      end

      it 'does add pods to the embed frameworks script' do
        @pod_target.stubs(:requires_frameworks? => true)
        @target.stubs(:requires_frameworks? => true)
        @installer.install!
        support_files_dir = config.sandbox.target_support_files_dir('Pods')
        script = support_files_dir + 'Pods-frameworks.sh'
        script.read.should.include?('BananaLib.framework')
      end

      it 'uniques resources by config' do
        a_path = Pathname.new(@project.path.dirname + '/duplicated/path.jpg')
        duplicated_paths = [a_path, a_path]
        @installer.target.pod_targets.each do |pod_target|
          pod_target.file_accessors.each do |accessor|
            accessor.stubs(:resources => duplicated_paths)
          end
        end
        resources_by_config = @installer.send(:resources_by_config)
        resources_by_config.each_value do |resources|
          resources.length.should == 1
          resources[0].basename.should == a_path.basename
        end
      end

      it 'does not add pods to the embed frameworks script if they are not to be built' do
        @pod_target.stubs(:should_build? => false)
        @pod_target.stubs(:requires_frameworks? => true)
        @target.stubs(:requires_frameworks? => true)
        @installer.install!
        support_files_dir = config.sandbox.target_support_files_dir('Pods')
        script = support_files_dir + 'Pods-frameworks.sh'
        script.read.should.not.include?('BananaLib.framework')
      end

      it 'creates the acknowledgements files ' do
        @installer.install!
        support_files_dir = config.sandbox.target_support_files_dir('Pods')
        markdown = support_files_dir + 'Pods-acknowledgements.markdown'
        markdown.read.should.include?('Permission is hereby granted')
        plist = support_files_dir + 'Pods-acknowledgements.plist'
        plist.read.should.include?('Permission is hereby granted')
      end

      it 'creates a dummy source to ensure the creation of a single base library' do
        @installer.install!
        build_files = @installer.target.native_target.source_build_phase.files
        build_file = build_files.find { |bf| bf.file_ref.path.include?('Pods-dummy.m') }
        build_file.should.be.not.nil
        build_file.file_ref.path.should == 'Pods-dummy.m'
        support_files_dir = config.sandbox.target_support_files_dir('Pods')
        dummy = support_files_dir + 'Pods-dummy.m'
        dummy.read.should.include?('@interface PodsDummy_Pods')
      end
    end
  end
end
