require File.expand_path('../../../../../spec_helper', __FILE__)

module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        describe PodTargetInstaller do
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
              file_accessor.resources.each do |resource|
                @project.add_file_reference(resource, group)
              end

              @pod_target = PodTarget.new([@spec], [@target_definition], config.sandbox)
              @pod_target.file_accessors = [file_accessor]
              @pod_target.user_build_configurations = { 'Debug' => :debug, 'Release' => :release }
              @installer = PodTargetInstaller.new(config.sandbox, @pod_target)

              @spec.prefix_header_contents = '#import "BlocksKit.h"'
            end

            it 'uses the maximum of all spec deployment targets' do
              spec_1 = Pod::Specification.new { |s| s.ios.deployment_target = '10.10' }
              spec_2 = Pod::Specification.new { |s| s.ios.deployment_target = '10.9' }
              spec_3 = Pod::Specification.new
              @pod_target.stubs(:specs).returns([spec_1, spec_2, spec_3])
              @installer.send(:deployment_target).should == '10.10'
            end

            it 'sets the platform and the deployment target for iOS targets' do
              @installer.install!
              target = @project.targets.first
              target.platform_name.should == :ios
              target.deployment_target.should == '4.3'
              target.build_settings('Debug')['IPHONEOS_DEPLOYMENT_TARGET'].should == '4.3'
            end

            it 'sets the platform and the deployment target for iOS targets that require frameworks' do
              @pod_target.stubs(:requires_frameworks?).returns(true)
              @installer.install!
              target = @project.targets.first
              target.platform_name.should == :ios
              target.deployment_target.should == '8.0'
              target.build_settings('Debug')['IPHONEOS_DEPLOYMENT_TARGET'].should == '8.0'
            end

            it 'sets the platform and the deployment target for OS X targets' do
              @pod_target.target_definitions.first.stubs(:platform).returns(Platform.new(:osx, '10.8'))
              @installer.install!
              target = @project.targets.first
              target.platform_name.should == :osx
              target.deployment_target.should == '10.6'
              target.build_settings('Debug')['MACOSX_DEPLOYMENT_TARGET'].should == '10.6'
            end

            it "adds the user's build configurations to the target" do
              @pod_target.user_build_configurations.merge!('AppStore' => :release, 'Test' => :debug)
              @installer.install!
              @project.targets.first.build_configurations.map(&:name).sort.should == %w( AppStore Debug Release Test        )
            end

            it 'it creates different hash instances for the build settings of various build configurations' do
              @installer.install!
              build_settings = @project.targets.first.build_configurations.map(&:build_settings)
              build_settings.map(&:object_id).uniq.count.should == 2
            end

            it 'does not enable the GCC_WARN_INHIBIT_ALL_WARNINGS flag by default' do
              @installer.install!
              @installer.target.native_target.build_configurations.each do |config|
                config.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'].should.be.nil
              end
            end

            it 'sets an empty codesigning identity for iOS/tvOS/watchOS' do
              @installer.install!
              @project.targets.first.build_configurations.each do |config|
                config.build_settings['CODE_SIGN_IDENTITY[sdk=appletvos*]'].should == ''
                config.build_settings['CODE_SIGN_IDENTITY[sdk=iphoneos*]'].should == ''
                config.build_settings['CODE_SIGN_IDENTITY[sdk=watchos*]'].should == ''
              end
            end

            #--------------------------------------#

            describe 'headers folder paths' do
              it 'does not set them for framework targets' do
                @pod_target.stubs(:requires_frameworks? => true)
                @installer.install!
                @project.targets.first.build_configurations.each do |config|
                  config.build_settings['PUBLIC_HEADERS_FOLDER_PATH'].should.be.nil
                  config.build_settings['PRIVATE_HEADERS_FOLDER_PATH'].should.be.nil
                end
              end

              it 'empties them for non-framework targets' do
                @installer.install!
                @project.targets.first.build_configurations.each do |config|
                  config.build_settings['PUBLIC_HEADERS_FOLDER_PATH'].should.be.empty
                  config.build_settings['PRIVATE_HEADERS_FOLDER_PATH'].should.be.empty
                end
              end
            end

            #--------------------------------------#

            describe 'setting the SWIFT_VERSION' do
              it 'does not set the version if not included by the target definition' do
                @installer.install!
                @project.targets.first.build_configurations.each do |config|
                  config.build_settings.should.not.include?('SWIFT_VERSION')
                end
              end

              it 'sets the version to the one specified in the target definition' do
                @target_definition.swift_version = '3.0'
                @installer.install!
                @project.targets.first.build_configurations.each do |config|
                  config.build_settings['SWIFT_VERSION'].should == '3.0'
                end
              end
            end

            describe 'test target generation' do
              before do
                config.sandbox.prepare
                @podfile = Podfile.new do
                  project 'SampleProject/SampleProject'
                  target 'SampleProject' do
                    platform :ios, '6.0'
                  end
                  target 'SampleProject2' do
                    platform :osx, '10.8'
                  end
                end
                @target_definition = @podfile.target_definitions['SampleProject']
                @target_definition2 = @podfile.target_definitions['SampleProject2']
                @project = Project.new(config.sandbox.project_path)
                config.sandbox.project = @project

                @coconut_spec = fixture_spec('coconut-lib/CoconutLib.podspec')

                # Add sources to the project.
                file_accessor = Sandbox::FileAccessor.new(Sandbox::PathList.new(fixture('coconut-lib')), @coconut_spec.consumer(:ios))
                @project.add_pod_group('CoconutLib', fixture('coconut-lib'))
                group = @project.group_for_spec('CoconutLib')
                file_accessor.source_files.each do |file|
                  @project.add_file_reference(file, group)
                end
                file_accessor.resources.each do |resource|
                  @project.add_file_reference(resource, group)
                end

                # Add test sources to the project.
                test_file_accessor = Sandbox::FileAccessor.new(Sandbox::PathList.new(fixture('coconut-lib')), @coconut_spec.test_specs.first.consumer(:ios))
                @project.add_pod_group('CoconutLibTests', fixture('coconut-lib'))
                group = @project.group_for_spec('CoconutLibTests')
                test_file_accessor.source_files.each do |file|
                  @project.add_file_reference(file, group)
                end
                test_file_accessor.resources.each do |resource|
                  @project.add_file_reference(resource, group)
                end

                @coconut_pod_target = PodTarget.new([@coconut_spec, *@coconut_spec.recursive_subspecs], [@target_definition], config.sandbox)
                @coconut_pod_target.file_accessors = [file_accessor, test_file_accessor]
                @coconut_pod_target.user_build_configurations = { 'Debug' => :debug, 'Release' => :release }
                @installer = PodTargetInstaller.new(config.sandbox, @coconut_pod_target)
                @coconut_pod_target2 = PodTarget.new([@coconut_spec, *@coconut_spec.recursive_subspecs], [@target_definition2], config.sandbox)
                @coconut_pod_target2.file_accessors = [file_accessor, test_file_accessor]
                @coconut_pod_target2.user_build_configurations = { 'Debug' => :debug, 'Release' => :release }
                @installer2 = PodTargetInstaller.new(config.sandbox, @coconut_pod_target2)
              end

              it 'adds the native test target to the project for iOS targets with code signing' do
                @installer.install!
                @project.targets.count.should == 2
                @project.targets.first.name.should == 'CoconutLib'
                native_test_target = @project.targets[1]
                native_test_target.name.should == 'CoconutLib-Unit-Tests'
                native_test_target.product_reference.name.should == 'CoconutLib-Unit-Tests'
                native_test_target.build_configurations.each do |bc|
                  bc.build_settings['PRODUCT_NAME'].should == 'CoconutLib-Unit-Tests'
                  bc.build_settings['CODE_SIGNING_REQUIRED'].should == 'YES'
                end
                native_test_target.symbol_type.should == :unit_test_bundle
                @coconut_pod_target.test_native_targets.count.should == 1
              end

              it 'adds the native test target to the project for OSX targets without code signing' do
                @installer2.install!
                @project.targets.count.should == 2
                @project.targets.first.name.should == 'CoconutLib'
                native_test_target = @project.targets[1]
                native_test_target.name.should == 'CoconutLib-Unit-Tests'
                native_test_target.product_reference.name.should == 'CoconutLib-Unit-Tests'
                native_test_target.build_configurations.each do |bc|
                  bc.build_settings['PRODUCT_NAME'].should == 'CoconutLib-Unit-Tests'
                  bc.build_settings['CODE_SIGNING_REQUIRED'].should.be.nil
                end
                native_test_target.symbol_type.should == :unit_test_bundle
                @coconut_pod_target2.test_native_targets.count.should == 1
              end

              it 'adds swiftSwiftOnoneSupport ld flag to the debug configuration' do
                @coconut_pod_target.stubs(:uses_swift?).returns(true)
                @installer.install!
                native_test_target = @project.targets[1]
                debug_configuration = native_test_target.build_configurations.find(&:debug?)
                debug_configuration.build_settings['OTHER_LDFLAGS'].sort.should == [
                  '$(inherited)',
                  '-lswiftSwiftOnoneSupport',
                ]
                release_configuration = native_test_target.build_configurations.find { |bc| bc.type == :release }
                release_configuration.build_settings['OTHER_LDFLAGS'].should.be.nil
              end

              it 'adds files to build phases correctly depending on the native target' do
                @installer.install!
                @project.targets.count.should == 2
                native_target = @project.targets[0]
                native_target.source_build_phase.files.count.should == 2
                native_target.source_build_phase.files.map(&:display_name).sort.should == [
                  'Coconut.m',
                  'CoconutLib-dummy.m',
                ]
                native_test_target = @project.targets[1]
                native_test_target.source_build_phase.files.count.should == 1
                native_test_target.source_build_phase.files.map(&:display_name).sort.should == [
                  'CoconutTests.m',
                ]
              end

              it 'adds xcconfig file reference for test native targets' do
                @installer.install!
                @project.support_files_group
                group = @project['Pods/CoconutLib/Support Files']
                group.children.map(&:display_name).sort.should.include 'CoconutLib.unit.xcconfig'
              end

              it 'does not add test header imports to umbrella header' do
                @coconut_pod_target.stubs(:requires_frameworks?).returns(true)
                @installer.install!
                content = @coconut_pod_target.umbrella_header_path.read
                content.should.not =~ /"CoconutTestHeader.h"/
              end

              it 'adds test xcconfig file reference for test resource bundle targets' do
                @coconut_spec.test_specs.first.resource_bundle = { 'CoconutLibTestResources' => ['Model.xcdatamodeld'] }
                @installer.install!
                @coconut_pod_target.resource_bundle_targets.count.should == 0
                @coconut_pod_target.test_resource_bundle_targets.count.should == 1
                test_resource_bundle_target = @project.targets.find { |t| t.name == 'CoconutLib-CoconutLibTestResources' }
                test_resource_bundle_target.build_configurations.each do |bc|
                  bc.base_configuration_reference.real_path.basename.to_s.should == 'CoconutLib.unit.xcconfig'
                  bc.build_settings['CONFIGURATION_BUILD_DIR'].should.be.nil
                end
              end
            end

            describe 'test other files under sources' do
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

                @minions_spec = fixture_spec('minions-lib/MinionsLib.podspec')

                # Add sources to the project.
                file_accessor = Sandbox::FileAccessor.new(Sandbox::PathList.new(fixture('minions-lib')), @minions_spec.consumer(:ios))
                @project.add_pod_group('MinionsLib', fixture('minions-lib'))
                group = @project.group_for_spec('MinionsLib')
                file_accessor.source_files.each do |file|
                  @project.add_file_reference(file, group) if file.fnmatch?('*.m') || file.fnmatch?('*.h')
                end

                @minions_pod_target = PodTarget.new([@minions_spec, *@minions_spec.recursive_subspecs], [@target_definition], config.sandbox)
                @minions_pod_target.file_accessors = [file_accessor]
                @minions_pod_target.user_build_configurations = { 'Debug' => :debug, 'Release' => :release }
                @installer = PodTargetInstaller.new(config.sandbox, @minions_pod_target)

                @first_json_file = file_accessor.source_files.find { |sf| sf.extname == '.json' }
              end

              it 'raises when references are missing for non-source files' do
                @minions_pod_target.stubs(:requires_frameworks?).returns(true)
                exception = lambda { @installer.install! }.should.raise Informative
                exception.message.should.include "Unable to find other source ref for #{@first_json_file} for target MinionsLib."
              end
            end

            #--------------------------------------#

            it 'adds the source files of each pod to the target of the Pod library' do
              @installer.install!
              names = @installer.target.native_target.source_build_phase.files.map { |bf| bf.file_ref.display_name }
              names.should.include('Banana.m')
            end

            describe 'deals with invalid source file references' do
              before do
                file_accessor = @pod_target.file_accessors.first
                @first_header_file = file_accessor.source_files.find { |sf| sf.extname == '.h' }
                @first_source_file = file_accessor.source_files.find { |sf| sf.extname == '.m' }
                @header_symlink_file = @first_header_file.dirname + "SymLinkOf-#{@first_header_file.basename}"
                @source_symlink_file = @first_source_file.dirname + "SymLinkOf-#{@first_source_file.basename}"
                FileUtils.rm_f(@header_symlink_file.to_s)
                FileUtils.rm_f(@source_symlink_file.to_s)
              end

              after do
                FileUtils.rm_f(@header_symlink_file.to_s)
                FileUtils.rm_f(@source_symlink_file.to_s)
              end

              it 'raises when source file reference is not found' do
                File.symlink(@first_source_file, @source_symlink_file)
                path_list = Sandbox::PathList.new(fixture('banana-lib'))
                file_accessor = Sandbox::FileAccessor.new(path_list, @spec.consumer(:ios))
                @pod_target.file_accessors = [file_accessor]
                exception = lambda { @installer.install! }.should.raise Informative
                exception.message.should.include "Unable to find source ref for #{@source_symlink_file} for target BananaLib."
              end

              it 'raises when header file reference is not found' do
                File.symlink(@first_header_file, @header_symlink_file)
                path_list = Sandbox::PathList.new(fixture('banana-lib'))
                file_accessor = Sandbox::FileAccessor.new(path_list, @spec.consumer(:ios))
                @pod_target.file_accessors = [file_accessor]
                exception = lambda { @installer.install! }.should.raise Informative
                exception.message.should.include "Unable to find header ref for #{@header_symlink_file} for target BananaLib."
              end

              it 'does not raise when header file reference is found' do
                File.symlink(@first_header_file, @header_symlink_file)
                path_list = Sandbox::PathList.new(fixture('banana-lib'))
                file_accessor = Sandbox::FileAccessor.new(path_list, @spec.consumer(:ios))
                @pod_target.file_accessors = [file_accessor]
                group = @project.group_for_spec('BananaLib')
                @project.add_file_reference(@header_symlink_file.to_s, group)
                lambda { @installer.install! }.should.not.raise
              end

              it 'does not raise when source file reference is found' do
                File.symlink(@first_source_file, @source_symlink_file)
                path_list = Sandbox::PathList.new(fixture('banana-lib'))
                file_accessor = Sandbox::FileAccessor.new(path_list, @spec.consumer(:ios))
                @pod_target.file_accessors = [file_accessor]
                group = @project.group_for_spec('BananaLib')
                @project.add_file_reference(@source_symlink_file.to_s, group)
                lambda { @installer.install! }.should.not.raise
              end
            end

            #--------------------------------------#

            it 'adds framework resources to the framework target' do
              @pod_target.stubs(:requires_frameworks? => true)
              @installer.install!
              resources = @project.targets.first.resources_build_phase.files
              resources.count.should > 0
              resource = resources.find { |res| res.file_ref.path.include?('logo-sidebar.png') }
              resource.should.be.not.nil

              resource = resources.find { |res| res.file_ref.path.include?('en.lproj') }
              resource.should.be.not.nil
            end

            #--------------------------------------#

            describe 'with a scoped pod target' do
              before do
                @pod_target = @pod_target.scoped.first
                @installer = PodTargetInstaller.new(config.sandbox, @pod_target)
              end

              it 'adds file references for the support files of the target' do
                @installer.install!
                group = @project['Pods/BananaLib/Support Files']
                group.children.map(&:display_name).sort.should == [
                  'BananaLib-Pods-SampleProject-dummy.m',
                  'BananaLib-Pods-SampleProject-prefix.pch',
                  'BananaLib-Pods-SampleProject.xcconfig',
                ]
              end

              it 'verifies keeping prefix header generation' do
                @pod_target.specs.first.stubs(:prefix_header_file).returns(true)
                @installer.install!
                group = @project['Pods/BananaLib/Support Files']
                group.children.map(&:display_name).sort.should == [
                  'BananaLib-Pods-SampleProject-dummy.m',
                  'BananaLib-Pods-SampleProject-prefix.pch',
                  'BananaLib-Pods-SampleProject.xcconfig',
                ]
              end

              it 'verifies disabling prefix header generation' do
                @pod_target.specs.first.stubs(:prefix_header_file).returns(false)
                @installer.install!
                group = @project['Pods/BananaLib/Support Files']
                group.children.map(&:display_name).sort.should == [
                  'BananaLib-Pods-SampleProject-dummy.m',
                  'BananaLib-Pods-SampleProject.xcconfig',
                ]
              end

              it 'adds the target for the static library to the project' do
                @installer.install!
                @project.targets.count.should == 1
                @project.targets.first.name.should == 'BananaLib-Pods-SampleProject'
              end

              describe 'resource bundle targets' do
                before do
                  @pod_target.file_accessors.first.stubs(:resource_bundles).returns('banana_bundle' => [])
                  @installer.install!
                  @bundle_target = @project.targets.find { |t| t.name == 'BananaLib-Pods-SampleProject-banana_bundle' }
                end

                it 'adds the resource bundle targets' do
                  @bundle_target.should.be.an.instance_of Xcodeproj::Project::Object::PBXNativeTarget
                  @bundle_target.product_reference.name.should == 'banana_bundle.bundle'
                  @bundle_target.product_reference.path.should == 'BananaLib-Pods-SampleProject-banana_bundle.bundle'
                  @bundle_target.platform_name.should == :ios
                  @bundle_target.deployment_target.should == '4.3'
                end

                it 'adds the build configurations to the resources bundle targets' do
                  file = config.sandbox.root + @pod_target.xcconfig_path
                  @bundle_target.build_configurations.each do |bc|
                    bc.base_configuration_reference.real_path.should == file
                  end
                end

                it 'sets the correct product name' do
                  @bundle_target.build_configurations.each do |bc|
                    bc.build_settings['PRODUCT_NAME'].should == 'banana_bundle'
                  end
                end

                it 'sets the correct Info.plist file path' do
                  @bundle_target.build_configurations.each do |bc|
                    bc.build_settings['INFOPLIST_FILE'].should == 'Target Support Files/BananaLib-Pods-SampleProject/ResourceBundle-banana_bundle-Info.plist'
                  end
                end

                it 'sets the correct build dir' do
                  @bundle_target.build_configurations.each do |bc|
                    bc.build_settings['CONFIGURATION_BUILD_DIR'].should == '$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)/BananaLib-Pods-SampleProject'
                  end
                end

                it 'sets the correct targeted device family for the resource bundle targets' do
                  @bundle_target.build_configurations.each do |bc|
                    bc.build_settings['TARGETED_DEVICE_FAMILY'].should == '1,2'
                  end
                end
              end
            end

            #--------------------------------------#

            describe 'with an unscoped pod target' do
              it 'adds file references for the support files of the target' do
                @installer.install!
                @project.support_files_group
                group = @project['Pods/BananaLib/Support Files']
                group.children.map(&:display_name).sort.should == [
                  'BananaLib-dummy.m',
                  'BananaLib-prefix.pch',
                  'BananaLib.xcconfig',
                ]
              end

              it 'verifies disabling prefix header generation' do
                @pod_target.specs.first.stubs(:prefix_header_file).returns(false)
                @installer.install!
                group = @project['Pods/BananaLib/Support Files']
                group.children.map(&:display_name).sort.should == [
                  'BananaLib-dummy.m',
                  'BananaLib.xcconfig',
                ]
              end

              it 'adds the target for the static library to the project' do
                @installer.install!
                @project.targets.count.should == 1
                @project.targets.first.name.should == 'BananaLib'
              end

              describe 'resource bundle targets' do
                before do
                  @pod_target.file_accessors.first.stubs(:resource_bundles).returns('banana_bundle' => [])
                  @installer.install!
                  @bundle_target = @project.targets.find { |t| t.name == 'BananaLib-banana_bundle' }
                end

                it 'adds the resource bundle targets' do
                  @bundle_target.should.be.an.instance_of Xcodeproj::Project::Object::PBXNativeTarget
                  @bundle_target.product_reference.name.should == 'banana_bundle.bundle'
                  @bundle_target.product_reference.path.should == 'BananaLib-banana_bundle.bundle'
                end

                it 'adds the build configurations to the resources bundle targets' do
                  file = config.sandbox.root + @pod_target.xcconfig_path
                  @bundle_target.build_configurations.each do |bc|
                    bc.base_configuration_reference.real_path.should == file
                  end
                end
              end
            end

            #--------------------------------------#

            it 'creates the xcconfig file' do
              @installer.install!
              file = config.sandbox.root + @pod_target.xcconfig_path
              xcconfig = Xcodeproj::Config.new(file)
              xcconfig.to_hash['PODS_ROOT'].should == '${SRCROOT}'
            end

            it "creates a prefix header, including the contents of the specification's prefix header" do
              @spec.prefix_header_contents = '#import "BlocksKit.h"'
              @installer.install!
              generated = @pod_target.prefix_header_path.read
              expected = <<-EOS.strip_heredoc
          #ifdef __OBJC__
          #import <UIKit/UIKit.h>
          #else
          #ifndef FOUNDATION_EXPORT
          #if defined(__cplusplus)
          #define FOUNDATION_EXPORT extern "C"
          #else
          #define FOUNDATION_EXPORT extern
          #endif
          #endif
          #endif

          #import "BlocksKit.h"
          #import <BananaTree/BananaTree.h>
              EOS
              generated.should == expected
            end

            it 'creates a dummy source to ensure the compilation of libraries with only categories' do
              @installer.install!
              dummy_source_basename = @pod_target.dummy_source_path.basename.to_s
              build_files = @installer.target.native_target.source_build_phase.files
              build_file = build_files.find { |bf| bf.file_ref.display_name == dummy_source_basename }
              build_file.should.be.not.nil
              build_file.file_ref.path.should == dummy_source_basename
              @pod_target.dummy_source_path.read.should.include?('@interface PodsDummy_BananaLib')
            end

            #--------------------------------------------------------------------------------#

            it 'does not create a target if the specification does not define source files' do
              @pod_target.file_accessors.first.stubs(:source_files).returns([])
              @installer.install!
              @project.targets.should == []
            end

            #--------------------------------------------------------------------------------#

            describe 'concerning header_mappings_dirs' do
              before do
                @project.add_pod_group('snake', fixture('snake'))

                @pod_target = fixture_pod_target('snake/snake.podspec', [@target_definition])
                @pod_target.user_build_configurations = { 'Debug' => :debug, 'Release' => :release }
                @pod_target.stubs(:requires_frameworks? => true)
                group = @project.group_for_spec('snake')
                @pod_target.file_accessors.first.source_files.each do |file|
                  @project.add_file_reference(file, group)
                end
                @installer.stubs(:target).returns(@pod_target)
              end

              it 'creates custom copy files phases for framework pods' do
                @installer.install!

                target = @project.native_targets.first
                target.name.should == 'snake'

                header_build_phase_file_refs = target.headers_build_phase.files.
                  reject { |build_file| build_file.settings.nil? }.
                  map { |build_file| build_file.file_ref.path }
                header_build_phase_file_refs.should == %w(
                  Code/C/Boa.h
                  Code/C/Garden.h
                  Code/C/Rattle.h
                  snake-umbrella.h
                )

                copy_files_build_phases = target.copy_files_build_phases.sort_by(&:name)
                copy_files_build_phases.map(&:name).should == [
                  'Copy . Public Headers',
                  'Copy A Public Headers',
                  'Copy B Private Headers',
                ]

                copy_files_build_phases.map(&:symbol_dst_subfolder_spec).should == Array.new(3, :products_directory)

                copy_files_build_phases.map(&:dst_path).should == [
                  '$(PUBLIC_HEADERS_FOLDER_PATH)/.',
                  '$(PUBLIC_HEADERS_FOLDER_PATH)/A',
                  '$(PRIVATE_HEADERS_FOLDER_PATH)/B',
                ]

                copy_files_build_phases.map { |phase| phase.files_references.map(&:path) }.should == [
                  ['Code/snake.h'],
                  ['Code/A/Boa.h', 'Code/A/Garden.h', 'Code/A/Rattle.h'],
                  ['Code/B/Boa.h', 'Code/B/Garden.h', 'Code/B/Rattle.h'],
                ]
              end

              it 'uses relative file paths to generate umbrella header' do
                @installer.install!

                content = @pod_target.umbrella_header_path.read
                content.should =~ %r{"A/Boa.h"}
                content.should =~ %r{"A/Garden.h"}
                content.should =~ %r{"A/Rattle.h"}
              end

              it 'creates a build phase to symlink header folders on OS X' do
                @pod_target.stubs(:platform).returns(Platform.osx)

                @installer.install!

                target = @project.native_targets.first
                build_phase = target.shell_script_build_phases.find do |bp|
                  bp.name == 'Create Symlinks to Header Folders'
                end
                build_phase.should.not.be.nil
              end

              it 'creates a build phase to set up a static library framework' do
                @pod_target.stubs(:static_framework?).returns(true)

                @installer.install!

                target = @project.native_targets.first
                build_phase = target.shell_script_build_phases.find do |bp|
                  bp.name == 'Setup Static Framework Archive'
                end
                build_phase.should.not.be.nil
              end
            end

            it "doesn't create a build phase to symlink header folders by default on OS X" do
              @pod_target.stubs(:platform).returns(Platform.osx)

              @installer.install!

              target = @project.native_targets.first
              target.shell_script_build_phases.should == []
            end

            #--------------------------------------------------------------------------------#

            describe 'concerning compiler flags' do
              before do
                @spec = Pod::Spec.new
              end

              it 'flags should not be added to dtrace files' do
                @installer.target.target_definitions.first.stubs(:inhibits_warnings_for_pod?).returns(true)
                @installer.install!

                dtrace_files = @installer.target.native_target.source_build_phase.files.select do |sf|
                  File.extname(sf.file_ref.path) == '.d'
                end
                dtrace_files.each do |dt|
                  dt.settings.should.be.nil
                end
              end

              it 'adds -w per pod if target definition inhibits warnings for that pod' do
                @installer.target.target_definitions.first.stubs(:inhibits_warnings_for_pod?).returns(true)
                flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios), true)

                flags.should.include?('-w')
              end

              it "doesn't inhibit warnings by default" do
                flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios), true)
                flags.should.not.include?('-w')
              end

              it 'adds -Xanalyzer -analyzer-disable-checker per pod' do
                @installer.target.target_definitions.first.stubs(:inhibits_warnings_for_pod?).returns(true)
                flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios), true)

                flags.should.include?('-Xanalyzer -analyzer-disable-all-checks')
              end

              it "doesn't inhibit analyzer warnings by default" do
                flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios), true)
                flags.should.not.include?('-Xanalyzer -analyzer-disable-all-checks')
              end

              describe 'concerning ARC before and after iOS 6.0 and OS X 10.8' do
                it 'does not do anything if ARC is *not* required' do
                  @spec.ios.deployment_target = '5'
                  @spec.osx.deployment_target = '10.6'
                  ios_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios), false)
                  osx_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:osx), false)
                  ios_flags.should.not.include '-DOS_OBJECT_USE_OBJC'
                  osx_flags.should.not.include '-DOS_OBJECT_USE_OBJC'
                end

                it 'does *not* disable the `OS_OBJECT_USE_OBJC` flag if ARC is required and has a deployment target of >= iOS 6.0 or OS X 10.8' do
                  @spec.ios.deployment_target = '6'
                  @spec.osx.deployment_target = '10.8'
                  ios_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios), false)
                  osx_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:osx), false)
                  ios_flags.should.not.include '-DOS_OBJECT_USE_OBJC'
                  osx_flags.should.not.include '-DOS_OBJECT_USE_OBJC'
                end

                it '*does* disable the `OS_OBJECT_USE_OBJC` flag if ARC is required but has a deployment target < iOS 6.0 or OS X 10.8' do
                  @spec.ios.deployment_target = '5.1'
                  @spec.osx.deployment_target = '10.7.2'
                  ios_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios), true)
                  osx_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:osx), true)
                  ios_flags.should.include '-DOS_OBJECT_USE_OBJC'
                  osx_flags.should.include '-DOS_OBJECT_USE_OBJC'
                end

                it '*does* disable the `OS_OBJECT_USE_OBJC` flag if ARC is required and *no* deployment target is specified' do
                  ios_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios), true)
                  osx_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:osx), true)
                  ios_flags.should.include '-DOS_OBJECT_USE_OBJC'
                  osx_flags.should.include '-DOS_OBJECT_USE_OBJC'
                end
              end
            end

            describe 'concerning resources' do
              before do
                config.sandbox.prepare

                @project = Project.new(config.sandbox.project_path)

                config.sandbox.project = @project

                @spec = fixture_spec('banana-lib/BananaLib.podspec')
                @spec.resources = ['Resources/**/*']
                @spec.resource_bundle = nil
                @project.add_pod_group('BananaLib', fixture('banana-lib'))

                @pod_target = fixture_pod_target(@spec)
                @pod_target.stubs(:requires_frameworks? => true)
                @pod_target.user_build_configurations = { 'Debug' => :debug, 'Release' => :release }
                target_installer = PodTargetInstaller.new(config.sandbox, @pod_target)

                # Use a file references installer to add the files so that the correct ones are added.
                file_ref_installer = Installer::Xcode::PodsProjectGenerator::FileReferencesInstaller.new(config.sandbox, [@pod_target], @project)
                file_ref_installer.install!

                target_installer.install!
              end

              it 'adds variant groups directly to resources' do
                native_target = @project.targets.first

                # The variant group item should be present.
                group_build_file = native_target.resources_build_phase.files.find do |bf|
                  bf.file_ref.path == 'Resources' && bf.file_ref.name == 'Main.storyboard'
                end

                group_build_file.should.be.not.nil
                group_build_file.file_ref.is_a?(Xcodeproj::Project::Object::PBXVariantGroup).should.be.true

                # An item within the variant group should not be present.
                strings_build_file = native_target.resources_build_phase.files.find do |bf|
                  bf.file_ref.path == 'Resources/en.lproj/Main.strings'
                end
                strings_build_file.should.be.nil
              end

              it 'adds Core Data models to the compile sources phase (non-bundles only)' do
                native_target = @project.targets.first

                # The data model should not be in the resources phase.
                core_data_resources_file = native_target.resources_build_phase.files.find do |bf|
                  bf.file_ref.path == 'Resources/Sample.xcdatamodeld'
                end
                core_data_resources_file.should.be.nil

                # The data model should not be in the resources phase.
                core_data_sources_file = native_target.source_build_phase.files.find do |bf|
                  bf.file_ref.path == 'Resources/Sample.xcdatamodeld'
                end
                core_data_sources_file.should.be.not.nil
              end
            end

            describe 'concerning resource bundles' do
              before do
                config.sandbox.prepare

                @project = Project.new(config.sandbox.project_path)

                config.sandbox.project = @project

                @spec = fixture_spec('banana-lib/BananaLib.podspec')
                @spec.resources = nil
                @spec.resource_bundle = { 'banana_bundle' => ['Resources/**/*'] }
                @project.add_pod_group('BananaLib', fixture('banana-lib'))

                @pod_target = fixture_pod_target(@spec)
                @pod_target.user_build_configurations = { 'Debug' => :debug, 'Release' => :release }
                target_installer = PodTargetInstaller.new(config.sandbox, @pod_target)

                # Use a file references installer to add the files so that the correct ones are added.
                file_ref_installer = Installer::Xcode::PodsProjectGenerator::FileReferencesInstaller.new(config.sandbox, [@pod_target], @project)
                file_ref_installer.install!

                target_installer.install!

                @bundle_target = @project.targets.find { |t| t.name == 'BananaLib-banana_bundle' }
                @bundle_target.should.be.not.nil
              end

              it 'adds variant groups directly to resource bundle' do
                # The variant group item should be present.
                group_build_file = @bundle_target.resources_build_phase.files.find do |bf|
                  bf.file_ref.path == 'Resources' && bf.file_ref.name == 'Main.storyboard'
                end
                group_build_file.should.be.not.nil
                group_build_file.file_ref.is_a?(Xcodeproj::Project::Object::PBXVariantGroup).should.be.true

                # An item within the variant group should not be present.
                strings_build_file = @bundle_target.resources_build_phase.files.find do |bf|
                  bf.file_ref.path == 'Resources/en.lproj/Main.strings'
                end
                strings_build_file.should.be.nil
              end

              it 'adds Core Data models directly to resource bundle' do
                # The model directory item should be present.
                dir_build_file = @bundle_target.resources_build_phase.files.find { |bf| bf.file_ref.path == 'Resources/Sample.xcdatamodeld' }
                dir_build_file.should.be.not.nil

                # An item within the model directory should not be present.
                version_build_file = @bundle_target.resources_build_phase.files.find do |bf|
                  bf.file_ref.path =~ %r{Resources/Sample.xcdatamodeld/Sample.xcdatamodel}i
                end
                version_build_file.should.be.nil
              end

              it 'adds Core Data migration mapping models directly to resources' do
                # The model directory item should be present.
                dir_build_file = @bundle_target.resources_build_phase.files.find { |bf| bf.file_ref.path == 'Resources/Migration.xcmappingmodel' }
                dir_build_file.should.be.not.nil

                # An item within the model directory should not be present.
                xml_file = @bundle_target.resources_build_phase.files.find do |bf|
                  bf.file_ref.path =~ %r{Resources/Migration\.xcmappingmodel/.*}i
                end
                xml_file.should.be.nil
              end
            end
          end
        end
      end
    end
  end
end
