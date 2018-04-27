require File.expand_path('../../../../../spec_helper', __FILE__)

module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        describe AggregateTargetInstaller do
          describe 'In General' do
            before do
              config.sandbox.prepare
              @podfile = Podfile.new do
                platform :ios, '6.0'
                project 'SampleProject/SampleProject'
                target 'SampleProject'
              end
              @target_definition = @podfile.target_definitions['SampleProject']
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

              user_build_configurations = { 'Debug' => :debug, 'Release' => :release, 'AppStore' => :release, 'Test' => :debug }
              @pod_target = PodTarget.new(config.sandbox, false, user_build_configurations, [], Platform.new(:ios, '6.0'), [@spec], [@target_definition], [file_accessor])
              pod_targets_by_config = Hash[user_build_configurations.each_key.map { |c| [c, [@pod_target]] }]
              @target = AggregateTarget.new(config.sandbox, false, user_build_configurations, [], Platform.new(:ios, '6.0'), @target_definition, config.sandbox.root.dirname, nil, nil, pod_targets_by_config)
              @installer = AggregateTargetInstaller.new(config.sandbox, @project, @target)
              @spec.prefix_header_contents = '#import "BlocksKit.h"'
            end

            it 'adds file references for the support files of the target' do
              @installer.install!
              group = @project.support_files_group['Pods-SampleProject']
              group.children.map(&:display_name).sort.should == [
                'Pods-SampleProject-acknowledgements.markdown',
                'Pods-SampleProject-acknowledgements.plist',
                'Pods-SampleProject-dummy.m',
                'Pods-SampleProject-frameworks.sh',
                'Pods-SampleProject-resources.sh',
                'Pods-SampleProject.appstore.xcconfig',
                'Pods-SampleProject.debug.xcconfig',
                'Pods-SampleProject.release.xcconfig',
                'Pods-SampleProject.test.xcconfig',
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
              @project.targets.first.build_configurations.map(&:name).sort.should == %w( AppStore Debug Release Test        )
            end

            it 'it creates different hash instances for the build settings of various build configurations' do
              @installer.install!
              build_settings = @project.targets.first.build_configurations.map(&:build_settings)
              build_settings.map(&:object_id).uniq.count.should == 4
            end

            it 'does not enable the GCC_WARN_INHIBIT_ALL_WARNINGS flag by default' do
              @installer.install!.native_target.build_configurations.each do |config|
                config.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'].should.be.nil
              end
            end

            it 'will be built as static library' do
              @installer.install!.native_target.build_configurations.each do |config|
                config.build_settings['MACH_O_TYPE'].should == 'staticlib'
              end
            end

            it 'will be skipped when installing' do
              @installer.install!.native_target.build_configurations.each do |config|
                config.build_settings['SKIP_INSTALL'].should == 'YES'
              end
            end

            it 'has a PRODUCT_BUNDLE_IDENTIFIER set' do
              @installer.install!.native_target.build_configurations.each do |config|
                config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'].should == 'org.cocoapods.${PRODUCT_NAME:rfc1034identifier}'
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
              support_files_dir = config.sandbox.target_support_files_dir('Pods-SampleProject')
              script = support_files_dir + 'Pods-SampleProject-resources.sh'
              script.read.should.include?('logo-sidebar.png')
            end

            it 'does not add framework resources to copy resources script' do
              @pod_target.stubs(:requires_frameworks? => true)
              @installer.install!
              support_files_dir = config.sandbox.target_support_files_dir('Pods-SampleProject')
              script = support_files_dir + 'Pods-SampleProject-resources.sh'
              script.read.should.not.include?('logo-sidebar.png')
            end

            it 'adds the resources bundles to the copy resources script' do
              @pod_target.file_accessors.first.stubs(:resource_bundles).returns(
                'Trees' => [Pathname('palm.jpg')],
                'Leafs' => [Pathname('leaf.jpg')],
              )
              resources_by_config = @target.resource_paths_by_config
              resources_by_config.each_value do |resources|
                resources.should.include '${PODS_CONFIGURATION_BUILD_DIR}/BananaLib/Trees.bundle'
                resources.should.include '${PODS_CONFIGURATION_BUILD_DIR}/BananaLib/Leafs.bundle'
              end
            end

            it 'adds the bridge support file to the copy resources script, if one was created' do
              Podfile.any_instance.stubs(:generate_bridge_support? => true)
              resources_by_config = @target.resource_paths_by_config
              resources_by_config.each_value do |resources|
                resources.should.include @installer.target.bridge_support_file
              end
            end

            it 'does add pods to the embed frameworks script' do
              @pod_target.stubs(:requires_frameworks? => true)
              @target.stubs(:requires_frameworks? => true)
              @installer.install!
              support_files_dir = config.sandbox.target_support_files_dir('Pods-SampleProject')
              script = support_files_dir + 'Pods-SampleProject-frameworks.sh'
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
              resources_by_config = @target.resource_paths_by_config
              resources_by_config.each_value do |resources|
                resources.length.should == 1
                Pathname.new(resources[0]).basename.should == a_path.basename
              end
            end

            it 'does not add pods to the embed frameworks script if they are not to be built' do
              @pod_target.stubs(:should_build? => false)
              @pod_target.stubs(:requires_frameworks? => true)
              @target.stubs(:requires_frameworks? => true)
              @installer.install!
              support_files_dir = config.sandbox.target_support_files_dir('Pods-SampleProject')
              script = support_files_dir + 'Pods-SampleProject-frameworks.sh'
              script.read.should.not.include?('BananaLib.framework')
            end

            it 'does not add pods to the embed frameworks script if they are static' do
              @pod_target.stubs(:static_framework? => true)
              @pod_target.stubs(:requires_frameworks? => true)
              @target.stubs(:requires_frameworks? => true)
              @installer.install!
              support_files_dir = config.sandbox.target_support_files_dir('Pods-SampleProject')
              script = support_files_dir + 'Pods-SampleProject-frameworks.sh'
              script.read.should.not.include?('BananaLib.framework')
            end

            it 'creates the acknowledgements files ' do
              @installer.install!
              support_files_dir = config.sandbox.target_support_files_dir('Pods-SampleProject')
              markdown = support_files_dir + 'Pods-SampleProject-acknowledgements.markdown'
              markdown.read.should.include?('Permission is hereby granted')
              plist = support_files_dir + 'Pods-SampleProject-acknowledgements.plist'
              plist.read.should.include?('Permission is hereby granted')
            end

            it 'creates a dummy source to ensure the creation of a single base library' do
              build_files = @installer.install!.native_target.source_build_phase.files
              build_file = build_files.find { |bf| bf.file_ref.path.include?('Pods-SampleProject-dummy.m') }
              build_file.should.be.not.nil
              build_file.file_ref.path.should == 'Pods-SampleProject-dummy.m'
              support_files_dir = config.sandbox.target_support_files_dir('Pods-SampleProject')
              dummy = support_files_dir + 'Pods-SampleProject-dummy.m'
              dummy.read.should.include?('@interface PodsDummy_Pods')
            end

            it 'creates an embed frameworks script, if the target does not require a host target' do
              @pod_target.stubs(:requires_frameworks? => true)
              @target.stubs(:requires_frameworks? => true)
              @installer.install!
              support_files_dir = config.sandbox.target_support_files_dir('Pods-SampleProject')
              script = support_files_dir + 'Pods-SampleProject-frameworks.sh'
              File.exist?(script).should == true
            end

            it 'does not create an embed frameworks script, if the target requires a host target' do
              @pod_target.stubs(:requires_frameworks? => true)
              @target.stubs(:requires_frameworks? => true)
              @target.stubs(:requires_host_target? => true)
              @installer.install!
              support_files_dir = config.sandbox.target_support_files_dir('Pods-SampleProject')
              script = support_files_dir + 'Pods-SampleProject-frameworks.sh'
              File.exist?(script).should == false
            end

            it 'installs umbrella headers for swift static libraries' do
              @pod_target.stubs(:uses_swift? => true)
              @target.stubs(:uses_swift? => true)
              build_files = @installer.install!.native_target.headers_build_phase.files
              build_file = build_files.find { |bf| bf.file_ref.path.include?('Pods-SampleProject-umbrella.h') }
              build_file.should.not.be.nil
              build_file.settings.should == { 'ATTRIBUTES' => ['Project'] }
            end

            it 'installs umbrella headers for frameworks' do
              @pod_target.stubs(:requires_frameworks? => true)
              @target.stubs(:requires_frameworks? => true)
              build_files = @installer.install!.native_target.headers_build_phase.files
              build_file = build_files.find { |bf| bf.file_ref.path.include?('Pods-SampleProject-umbrella.h') }
              build_file.should.not.be.nil
              build_file.settings.should == { 'ATTRIBUTES' => ['Public'] }
            end
          end
        end
      end
    end
  end
end
