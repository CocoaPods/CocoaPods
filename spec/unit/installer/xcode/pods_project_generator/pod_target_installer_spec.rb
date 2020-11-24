require File.expand_path('../../../../../spec_helper', __FILE__)

module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        describe PodTargetInstaller do
          describe 'In General' do
            before do
              @banana_spec = fixture_spec('banana-lib/BananaLib.podspec')
              @project = Pod::Project.new(config.sandbox.project_path)
              @project.add_pod_group('BananaLib', fixture('banana-lib'))
              platform = Platform.new(:ios, '4.3')
              @target_definition = fixture_target_definition('SampleProject', platform)
              @pod_target = fixture_pod_target(@banana_spec, BuildType.static_library,
                                               { 'Debug' => :debug, 'Release' => :release }, [], platform,
                                               [@target_definition])
              FileReferencesInstaller.new(config.sandbox, [@pod_target], @project).install!
              @installer = PodTargetInstaller.new(config.sandbox, @project, @pod_target)
            end

            it 'sets the platform and the deployment target for iOS targets' do
              @installer.install!
              target = @project.targets.first
              target.platform_name.should == :ios
              target.deployment_target.should == '4.3'
              target.build_settings('Debug')['IPHONEOS_DEPLOYMENT_TARGET'].should == '4.3'
            end

            it 'sets the platform and the deployment target for iOS targets that require frameworks' do
              @pod_target.stubs(:platform).returns(Platform.new(:ios, '8.0'))
              @pod_target.stubs(:build_type).returns(BuildType.dynamic_framework)
              @installer.install!
              target = @project.targets.first
              target.platform_name.should == :ios
              target.deployment_target.should == '8.0'
              target.build_settings('Debug')['IPHONEOS_DEPLOYMENT_TARGET'].should == '8.0'
            end

            it 'sets the platform and the deployment target for OS X targets' do
              @pod_target.stubs(:platform).returns(Platform.new(:osx, '10.6'))
              @installer.install!
              target = @project.targets.first
              target.platform_name.should == :osx
              target.deployment_target.should == '10.6'
              target.build_settings('Debug')['MACOSX_DEPLOYMENT_TARGET'].should == '10.6'
            end

            it "adds the user's build configurations to the target" do
              @pod_target.user_build_configurations.merge!('AppStore' => :release, 'Test' => :debug)
              @installer.install!
              @project.targets.first.build_configurations.map(&:name).sort.should == %w(AppStore Debug Release Test)
            end

            it 'it creates different hash instances for the build settings of various build configurations' do
              @installer.install!
              build_settings = @project.targets.first.build_configurations.map(&:build_settings)
              build_settings.map(&:object_id).uniq.count.should == 2
            end

            it 'does not enable the GCC_WARN_INHIBIT_ALL_WARNINGS flag by default' do
              @installer.install!.native_target.build_configurations.each do |config|
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

            it 'respects INFOPLIST_FILE of pod_target_xcconfig' do
              @banana_spec.pod_target_xcconfig = {
                'INFOPLIST_FILE' => 'somefile.plist',
              }
              @installer.install!
              @project.targets.first.build_configurations.each do |config|
                config.resolve_build_setting('INFOPLIST_FILE').should == 'somefile.plist'
              end
            end

            it 'adds bundle identifier from info_plist to build settings' do
              @banana_spec.info_plist = {
                'CFBundleIdentifier' => 'some.bundle.id',
              }
              @installer.install!
              @project.targets.first.build_configurations.each do |config|
                config.resolve_build_setting('PRODUCT_BUNDLE_IDENTIFIER').should == 'some.bundle.id'
              end
            end

            it 'cleans up temporary directories' do
              @installer.expects(:clean_support_files_temp_dir).once
              @installer.install!
            end

            describe 'info_plist_bundle_id' do
              it 'cache and return CFBundleIdentifier value when present in info_plist hash' do
                @installer.target.root_spec.info_plist = { 'CFBundleIdentifier' => 'CocoaPods.test.id' }
                @installer.send(:info_plist_bundle_id).should == 'CocoaPods.test.id'
                @installer.instance_variable_get(:@plist_bundle_id).should == 'CocoaPods.test.id'
              end

              it 'logs warning when CFBundleIdentifier value present in info_plist hash' do
                @installer.target.root_spec.info_plist = { 'CFBundleIdentifier' => 'CocoaPods.test.id' }
                @installer.send(:info_plist_bundle_id)
                UI.warnings.should.include 'The `BananaLib` target ' \
              'sets a Bundle Identifier of `CocoaPods.test.id` in it\'s info.plist file. ' \
              'The Bundle Identifier should be set using pod_target_xcconfig: ' \
              's.pod_target_xcconfig = { \'PRODUCT_BUNDLE_IDENTIFIER\': \'CocoaPods.test.id\' }`.'
              end

              it 'returns nil with no CFBundleIdentifier info_plist hash' do
                @installer.target.root_spec.info_plist = nil
                @installer.send(:info_plist_bundle_id).should.nil?
                @installer.target.root_spec.info_plist = {}
                @installer.send(:info_plist_bundle_id).should.nil?
                @installer.instance_variable_get(:@plist_bundle_id).should.nil?
                UI.warnings.should.not.include 'The `BananaLib` target ' \
              'sets a Bundle Identifier of `CocoaPods.test.id` in it\'s info.plist file. ' \
              'The Bundle Identifier should be set using pod_target_xcconfig: ' \
              's.pod_target_xcconfig = { \'PRODUCT_BUNDLE_IDENTIFIER\': \'CocoaPods.test.id\' }`.'
              end
            end

            #--------------------------------------#

            describe 'headers folder paths' do
              it 'does not set them for framework targets' do
                @pod_target.stubs(:build_type => BuildType.dynamic_framework)
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

              it 'sets the version to the one specified in by the pod target' do
                pod_target = fixture_pod_target(@banana_spec, BuildType.static_library,
                                                { 'Debug' => :debug, 'Release' => :release }, [], Platform.ios,
                                                [@target_definition], nil, '3.0')
                installer = PodTargetInstaller.new(config.sandbox, @project, pod_target)
                installer.install!
                @project.targets.first.build_configurations.each do |config|
                  config.build_settings['SWIFT_VERSION'].should == '3.0'
                end
              end
            end

            describe 'non-library target generation' do
              before do
                @banana_spec = fixture_spec('banana-lib/BananaLib.podspec')
                @watermelon_spec = fixture_spec('watermelon-lib/WatermelonLib.podspec')
                @project = Project.new(config.sandbox.project_path)
                @project.add_pod_group('WatermelonLib', fixture('watermelon-lib'))
                @ios_target_definition = fixture_target_definition('SampleProject', Platform.new(:ios, '6.0'))
                @osx_target_definition = fixture_target_definition('SampleProject2', Platform.new(:osx, '10.8'))
                user_build_configurations = { 'Debug' => :debug, 'Release' => :release }
                all_specs = [@watermelon_spec, *@watermelon_spec.recursive_subspecs]
                @banana_target = fixture_pod_target_with_specs([@banana_spec], BuildType.dynamic_framework,
                                                               user_build_configurations, [],
                                                               Platform.new(:ios, '6.0'),
                                                               [@ios_target_definition])

                @watermelon_ios_pod_target = fixture_pod_target_with_specs(all_specs, BuildType.static_library,
                                                                           user_build_configurations, [],
                                                                           Platform.new(:ios, '6.0'),
                                                                           [@ios_target_definition])
                @watermelon_osx_pod_target = fixture_pod_target_with_specs(all_specs, BuildType.static_library,
                                                                           user_build_configurations, [],
                                                                           Platform.new(:osx, '10.8'),
                                                                           [@osx_target_definition])
                FileReferencesInstaller.new(config.sandbox, [@watermelon_ios_pod_target, @watermelon_osx_pod_target],
                                            @project).install!
                @ios_installer = PodTargetInstaller.new(config.sandbox, @project, @watermelon_ios_pod_target)
                @osx_installer = PodTargetInstaller.new(config.sandbox, @project, @watermelon_osx_pod_target)
              end

              it 'adds the native test target to the project for iOS targets with correct build settings' do
                @watermelon_spec.app_specs.each { |s| s.pod_target_xcconfig = {} }
                installation_result = @ios_installer.install!
                @project.targets.count.should == 9
                @project.targets.first.name.should == 'WatermelonLib'
                unit_test_native_target = @project.targets[1]
                unit_test_native_target.name.should == 'WatermelonLib-Unit-Tests'
                unit_test_native_target.product_reference.name.should == 'WatermelonLib-Unit-Tests'
                unit_test_native_target.product_reference.path.should == 'WatermelonLib-Unit-Tests.xctest'
                unit_test_native_target.build_configurations.each do |bc|
                  bc.base_configuration_reference.real_path.basename.to_s.should == "WatermelonLib.unit-tests.#{bc.name.downcase}.xcconfig"
                  bc.build_settings['PRODUCT_NAME'].should == 'WatermelonLib-Unit-Tests'
                  bc.build_settings['MACH_O_TYPE'].should.be.nil
                  bc.build_settings['PRODUCT_MODULE_NAME'].should.be.nil
                  bc.build_settings['CODE_SIGNING_REQUIRED'].should == 'YES'
                  bc.build_settings['CODE_SIGNING_ALLOWED'].should == 'YES'
                  bc.build_settings['CODE_SIGN_IDENTITY'].should == 'iPhone Developer'
                  bc.build_settings['INFOPLIST_FILE'].should == 'Target Support Files/WatermelonLib/WatermelonLib-Unit-Tests-Info.plist'
                  bc.build_settings['GCC_PREFIX_HEADER'].should == 'Target Support Files/WatermelonLib/WatermelonLib-Unit-Tests-prefix.pch'
                end
                unit_test_native_target.symbol_type.should == :unit_test_bundle

                ui_test_native_target = @project.targets[2]
                ui_test_native_target.name.should == 'WatermelonLib-UI-UITests'
                ui_test_native_target.product_reference.name.should == 'WatermelonLib-UI-UITests'
                ui_test_native_target.product_reference.path.should == 'WatermelonLib-UI-UITests.xctest'
                ui_test_native_target.build_configurations.each do |bc|
                  bc.base_configuration_reference.real_path.basename.to_s.should == "WatermelonLib.ui-uitests.#{bc.name.downcase}.xcconfig"
                  bc.build_settings['PRODUCT_NAME'].should == 'WatermelonLib-UI-UITests'
                  bc.build_settings['MACH_O_TYPE'].should.be.nil
                  bc.build_settings['PRODUCT_MODULE_NAME'].should.be.nil
                  bc.build_settings['CODE_SIGNING_REQUIRED'].should == 'YES'
                  bc.build_settings['CODE_SIGNING_ALLOWED'].should == 'YES'
                  bc.build_settings['CODE_SIGN_IDENTITY'].should == 'iPhone Developer'
                  bc.build_settings['INFOPLIST_FILE'].should == 'Target Support Files/WatermelonLib/WatermelonLib-UI-UITests-Info.plist'
                  bc.build_settings['GCC_PREFIX_HEADER'].should == 'Target Support Files/WatermelonLib/WatermelonLib-UI-UITests-prefix.pch'
                end
                ui_test_native_target.symbol_type.should == :ui_test_bundle

                snapshot_test_native_target = @project.targets[3]
                snapshot_test_native_target.name.should == 'WatermelonLib-Unit-SnapshotTests'
                snapshot_test_native_target.product_reference.name.should == 'WatermelonLib-Unit-SnapshotTests'
                snapshot_test_native_target.product_reference.path.should == 'WatermelonLib-Unit-SnapshotTests.xctest'
                snapshot_test_native_target.build_configurations.each do |bc|
                  bc.base_configuration_reference.real_path.basename.to_s.should == "WatermelonLib.unit-snapshottests.#{bc.name.downcase}.xcconfig"
                  bc.build_settings['PRODUCT_NAME'].should == 'WatermelonLib-Unit-SnapshotTests'
                  bc.build_settings['MACH_O_TYPE'].should.be.nil
                  bc.build_settings['PRODUCT_MODULE_NAME'].should.be.nil
                  bc.build_settings['CODE_SIGNING_REQUIRED'].should == 'YES'
                  bc.build_settings['CODE_SIGNING_ALLOWED'].should == 'YES'
                  bc.build_settings['CODE_SIGN_IDENTITY'].should == 'iPhone Developer'
                  bc.build_settings['INFOPLIST_FILE'].should == 'Target Support Files/WatermelonLib/WatermelonLib-Unit-SnapshotTests-Info.plist'
                  bc.build_settings['GCC_PREFIX_HEADER'].should == 'Target Support Files/WatermelonLib/WatermelonLib-Unit-SnapshotTests-prefix.pch'
                end
                snapshot_test_native_target.symbol_type.should == :unit_test_bundle
                app_native_target = @project.targets[7]
                app_native_target.name.should == 'WatermelonLib-App'
                app_native_target.product_reference.name.should == 'WatermelonLib-App'
                app_native_target.product_reference.path.should == 'WatermelonLib-App.app'
                app_native_target.build_configurations.each do |bc|
                  bc.base_configuration_reference.real_path.basename.to_s.should == "WatermelonLib.app.#{bc.name.downcase}.xcconfig"
                  bc.build_settings['PRODUCT_NAME'].should == 'WatermelonLib-App'
                  bc.build_settings['PRODUCT_BUNDLE_IDENTIFIER'].should == 'org.cocoapods.${PRODUCT_NAME:rfc1034identifier}'
                  bc.build_settings['CURRENT_PROJECT_VERSION'].should == '1'
                  bc.build_settings['MACH_O_TYPE'].should.be.nil
                  bc.build_settings['PRODUCT_MODULE_NAME'].should.be.nil
                  bc.build_settings['CODE_SIGNING_REQUIRED'].should == 'YES'
                  bc.build_settings['CODE_SIGNING_ALLOWED'].should == 'YES'
                  bc.build_settings['CODE_SIGN_IDENTITY'].should == 'iPhone Developer'
                  bc.build_settings['CODE_SIGN_IDENTITY[sdk=appletvos*]'].should.be.nil
                  bc.build_settings['CODE_SIGN_IDENTITY[sdk=iphoneos*]'].should.be.nil
                  bc.build_settings['CODE_SIGN_IDENTITY[sdk=watchos*]'].should.be.nil
                  bc.build_settings['INFOPLIST_FILE'].should == 'App/WatermelonLib-App-Info.plist'
                  bc.build_settings['GCC_PREFIX_HEADER'].should == 'Target Support Files/WatermelonLib/WatermelonLib-App-prefix.pch'
                end
                app_native_target.symbol_type.should == :application
                installation_result.test_native_targets.count.should == 3
                installation_result.app_native_targets.count.should == 1
              end

              it 'adds the native test target to the project for OSX targets with correct build settings' do
                @watermelon_spec.app_specs.each { |s| s.pod_target_xcconfig = {} }
                installation_result = @osx_installer.install!
                @project.targets.count.should == 9
                @project.targets.first.name.should == 'WatermelonLib'
                unit_test_native_target = @project.targets[1]
                unit_test_native_target.product_reference.name.should == 'WatermelonLib-Unit-Tests'
                unit_test_native_target.product_reference.path.should == 'WatermelonLib-Unit-Tests.xctest'
                unit_test_native_target.build_configurations.each do |bc|
                  bc.base_configuration_reference.real_path.basename.to_s.should == "WatermelonLib.unit-tests.#{bc.name.downcase}.xcconfig"
                  bc.build_settings['PRODUCT_NAME'].should == 'WatermelonLib-Unit-Tests'
                  bc.build_settings['MACH_O_TYPE'].should.be.nil
                  bc.build_settings['PRODUCT_MODULE_NAME'].should.be.nil
                  bc.build_settings['CODE_SIGNING_REQUIRED'].should.be.nil
                  bc.build_settings['CODE_SIGNING_ALLOWED'].should.be.nil
                  bc.build_settings['CODE_SIGN_IDENTITY'].should == ''
                  bc.build_settings['INFOPLIST_FILE'].should == 'Target Support Files/WatermelonLib/WatermelonLib-Unit-Tests-Info.plist'
                  bc.build_settings['GCC_PREFIX_HEADER'].should == 'Target Support Files/WatermelonLib/WatermelonLib-Unit-Tests-prefix.pch'
                end

                ui_test_native_target = @project.targets[2]
                ui_test_native_target.name.should == 'WatermelonLib-UI-UITests'
                ui_test_native_target.product_reference.name.should == 'WatermelonLib-UI-UITests'
                ui_test_native_target.product_reference.path.should == 'WatermelonLib-UI-UITests.xctest'
                ui_test_native_target.build_configurations.each do |bc|
                  bc.base_configuration_reference.real_path.basename.to_s.should == "WatermelonLib.ui-uitests.#{bc.name.downcase}.xcconfig"
                  bc.build_settings['PRODUCT_NAME'].should == 'WatermelonLib-UI-UITests'
                  bc.build_settings['MACH_O_TYPE'].should.be.nil
                  bc.build_settings['PRODUCT_MODULE_NAME'].should.be.nil
                  bc.build_settings['CODE_SIGNING_REQUIRED'].should.be.nil
                  bc.build_settings['CODE_SIGNING_ALLOWED'].should.be.nil
                  bc.build_settings['CODE_SIGN_IDENTITY'].should == ''
                  bc.build_settings['INFOPLIST_FILE'].should == 'Target Support Files/WatermelonLib/WatermelonLib-UI-UITests-Info.plist'
                  bc.build_settings['GCC_PREFIX_HEADER'].should == 'Target Support Files/WatermelonLib/WatermelonLib-UI-UITests-prefix.pch'
                end
                ui_test_native_target.symbol_type.should == :ui_test_bundle

                snapshot_test_native_target = @project.targets[3]
                snapshot_test_native_target.name.should == 'WatermelonLib-Unit-SnapshotTests'
                snapshot_test_native_target.product_reference.name.should == 'WatermelonLib-Unit-SnapshotTests'
                snapshot_test_native_target.product_reference.path.should == 'WatermelonLib-Unit-SnapshotTests.xctest'
                snapshot_test_native_target.build_configurations.each do |bc|
                  bc.base_configuration_reference.real_path.basename.to_s.should == "WatermelonLib.unit-snapshottests.#{bc.name.downcase}.xcconfig"
                  bc.build_settings['PRODUCT_NAME'].should == 'WatermelonLib-Unit-SnapshotTests'
                  bc.build_settings['MACH_O_TYPE'].should.be.nil
                  bc.build_settings['PRODUCT_MODULE_NAME'].should.be.nil
                  bc.build_settings['CODE_SIGNING_REQUIRED'].should.be.nil
                  bc.build_settings['CODE_SIGNING_ALLOWED'].should.be.nil
                  bc.build_settings['CODE_SIGN_IDENTITY'].should == ''
                  bc.build_settings['INFOPLIST_FILE'].should == 'Target Support Files/WatermelonLib/WatermelonLib-Unit-SnapshotTests-Info.plist'
                  bc.build_settings['GCC_PREFIX_HEADER'].should == 'Target Support Files/WatermelonLib/WatermelonLib-Unit-SnapshotTests-prefix.pch'
                end
                snapshot_test_native_target.symbol_type.should == :unit_test_bundle
                app_native_target = @project.targets[7]
                app_native_target.name.should == 'WatermelonLib-App'
                app_native_target.product_reference.name.should == 'WatermelonLib-App'
                app_native_target.product_reference.path.should == 'WatermelonLib-App.app'
                app_native_target.build_configurations.each do |bc|
                  bc.base_configuration_reference.real_path.basename.to_s.should == "WatermelonLib.app.#{bc.name.downcase}.xcconfig"
                  bc.build_settings['PRODUCT_NAME'].should == 'WatermelonLib-App'
                  bc.build_settings['PRODUCT_BUNDLE_IDENTIFIER'].should == 'org.cocoapods.${PRODUCT_NAME:rfc1034identifier}'
                  bc.build_settings['CURRENT_PROJECT_VERSION'].should == '1'
                  bc.build_settings['CODE_SIGN_IDENTITY'].should == ''
                  bc.build_settings['MACH_O_TYPE'].should.be.nil
                  bc.build_settings['PRODUCT_MODULE_NAME'].should.be.nil
                  bc.build_settings['CODE_SIGN_IDENTITY'].should == ''
                  bc.build_settings['INFOPLIST_FILE'].should == 'App/WatermelonLib-App-Info.plist'
                  bc.build_settings['GCC_PREFIX_HEADER'].should == 'Target Support Files/WatermelonLib/WatermelonLib-App-prefix.pch'
                end
                app_native_target.symbol_type.should == :application
                installation_result.test_native_targets.count.should == 3
                installation_result.app_native_targets.count.should == 1
              end

              it 'raises when a test spec has no source files' do
                @watermelon_ios_pod_target.test_spec_consumers.first.stubs(:source_files).returns([])
                e = ->() { @ios_installer.install! }.should.raise Informative
                e.message.should.
                    include 'Unable to install the `WatermelonLib` pod, because the `WatermelonLib-Unit-Tests` target in Xcode would have no sources to compile.'
              end

              it 'raises when an app spec has no source files' do
                @watermelon_ios_pod_target.app_spec_consumers.first.stubs(:source_files).returns([])
                e = ->() { @ios_installer.install! }.should.raise Informative
                e.message.should.
                    include 'Unable to install the `WatermelonLib` pod, because the `WatermelonLib-App` target in Xcode would have no sources to compile.'
              end

              it 'adds files to build phases correctly depending on the native target' do
                @ios_installer.install!
                @project.targets.count.should == 9
                native_target = @project.targets[0]
                native_target.source_build_phase.files.count.should == 2
                native_target.source_build_phase.files.map(&:display_name).sort.should == [
                  'Watermelon.m',
                  'WatermelonLib-dummy.m',
                ]
                unit_test_native_target = @project.targets[1]
                unit_test_native_target.source_build_phase.files.count.should == 2
                unit_test_native_target.source_build_phase.files.map(&:display_name).sort.should == [
                  'WatermelonSwiftTests.swift',
                  'WatermelonTests.m',
                ]
                ui_test_native_target = @project.targets[2]
                ui_test_native_target.source_build_phase.files.count.should == 1
                ui_test_native_target.source_build_phase.files.map(&:display_name).sort.should == [
                  'WatermelonUITests.m',
                ]
                snapshot_test_native_target = @project.targets[3]
                snapshot_test_native_target.source_build_phase.files.count.should == 1
                snapshot_test_native_target.source_build_phase.files.map(&:display_name).sort.should == [
                  'WatermelonSnapshotTests.m',
                ]
                app_native_target = @project.targets[7]
                app_native_target.source_build_phase.files.count.should == 1
                app_native_target.source_build_phase.files.map(&:display_name).sort.should == [
                  'main.swift',
                ]
              end

              it 'adds xcconfig file reference for test native targets' do
                @ios_installer.install!
                group = @project['Pods/WatermelonLib/Support Files']
                group.children.map(&:display_name).sort.should.include 'WatermelonLib.unit-tests.debug.xcconfig'
                group.children.map(&:display_name).sort.should.include 'WatermelonLib.unit-tests.release.xcconfig'
                group.children.map(&:display_name).sort.should.include 'WatermelonLib.unit-snapshottests.debug.xcconfig'
                group.children.map(&:display_name).sort.should.include 'WatermelonLib.unit-snapshottests.release.xcconfig'
              end

              it 'adds xcconfig file reference for app native targets' do
                @ios_installer.install!
                group = @project['Pods/WatermelonLib/Support Files']
                group.children.map(&:display_name).sort.should.include 'WatermelonLib.app.debug.xcconfig'
                group.children.map(&:display_name).sort.should.include 'WatermelonLib.app.release.xcconfig'
              end

              it 'does not add test header imports to umbrella header' do
                @watermelon_ios_pod_target.stubs(:build_type).returns(BuildType.dynamic_framework)
                @ios_installer.install!
                content = @watermelon_ios_pod_target.umbrella_header_path.read
                content.should.not =~ /"CoconutTestHeader.h"/
              end

              it 'uses header_dir to umbrella header imports' do
                @watermelon_ios_pod_target.file_accessors.first.spec_consumer.stubs(:header_dir).returns('Watermelon')
                @watermelon_ios_pod_target.stubs(:build_type).returns(BuildType.static_library)
                @watermelon_ios_pod_target.stubs(:defines_module?).returns(true)
                @ios_installer.install!
                content = @watermelon_ios_pod_target.umbrella_header_path.read
                content.should =~ %r{"Watermelon/Watermelon.h"}
              end

              it 'uses header_dir and header_mappings_dir to umbrella header imports' do
                @watermelon_ios_pod_target.file_accessors.first.spec_consumer.stubs(:header_dir).returns('Watermelon2')
                @watermelon_ios_pod_target.file_accessors.first.spec_consumer.stubs(:header_mappings_dir).returns('Classes')
                @watermelon_ios_pod_target.stubs(:build_type).returns(BuildType.static_library)
                @watermelon_ios_pod_target.stubs(:defines_module?).returns(true)
                @ios_installer.install!
                content = @watermelon_ios_pod_target.umbrella_header_path.read
                content.should =~ %r{"Watermelon2/Watermelon.h"}
              end

              it 'does not use header_dir to umbrella header imports' do
                @watermelon_ios_pod_target.file_accessors.first.spec_consumer.stubs(:header_dir).returns('Watermelon')
                @watermelon_ios_pod_target.stubs(:build_type).returns(BuildType.dynamic_framework)
                @watermelon_ios_pod_target.stubs(:defines_module?).returns(true)
                @ios_installer.install!
                content = @watermelon_ios_pod_target.umbrella_header_path.read
                content.should.not =~ %r{"Watermelon/Watermelon.h"}
                content.should =~ /"Watermelon.h"/
              end

              it 'adds test xcconfig file reference for test resource bundle targets' do
                installation_result = @ios_installer.install!
                installation_result.resource_bundle_targets.count.should == 0
                installation_result.test_resource_bundle_targets.count.should == 3
                unit_test_resource_bundle_target = @project.targets.find { |t| t.name == 'WatermelonLib-WatermelonLibTestResources' }
                unit_test_resource_bundle_target.build_configurations.each do |bc|
                  bc.base_configuration_reference.real_path.basename.to_s.should == "WatermelonLib.unit-tests.#{bc.name.downcase}.xcconfig"
                  bc.build_settings['CONFIGURATION_BUILD_DIR'].should.be.nil
                end
                @project.targets.find { |t| t.name == 'WatermelonLib-WatermelonLibSnapshotTestResources' }.should.be.nil
              end

              it 'creates embed frameworks script for test target' do
                @watermelon_ios_pod_target.stubs(:build_type => BuildType.dynamic_framework)
                @ios_installer.install!
                script_path = @watermelon_ios_pod_target.embed_frameworks_script_path_for_spec(@watermelon_ios_pod_target.test_specs.first)
                script = script_path.read
                @watermelon_ios_pod_target.user_build_configurations.keys.each do |configuration|
                  script.should.include <<-eos.strip_heredoc
        if [[ "$CONFIGURATION" == "#{configuration}" ]]; then
          install_framework "${BUILT_PRODUCTS_DIR}/WatermelonLib/WatermelonLib.framework"
        fi
                  eos
                end
              end

              it 'creates embed frameworks script for app target' do
                @watermelon_ios_pod_target.stubs(:build_type => BuildType.dynamic_framework)
                @ios_installer.install!
                script_path = @watermelon_ios_pod_target.embed_frameworks_script_path_for_spec(@watermelon_ios_pod_target.app_specs.first)
                script = script_path.read
                @watermelon_ios_pod_target.user_build_configurations.keys.each do |configuration|
                  script.should.include <<-eos.strip_heredoc
        if [[ "$CONFIGURATION" == "#{configuration}" ]]; then
          install_framework "${BUILT_PRODUCTS_DIR}/WatermelonLib/WatermelonLib.framework"
        fi
                  eos
                end
              end

              it 'creates embed frameworks script for app target that includes framework paths from dependencies' do
                @watermelon_ios_pod_target.dependent_targets = [@banana_target]
                @watermelon_ios_pod_target.stubs(:framework_paths).returns('WatermelonLib' => [])
                @watermelon_ios_pod_target.stubs(:build_type => BuildType.dynamic_framework)
                @ios_installer.install!
                script_path = @watermelon_ios_pod_target.embed_frameworks_script_path_for_spec(@watermelon_ios_pod_target.app_specs.first)
                script = script_path.read
                @watermelon_ios_pod_target.user_build_configurations.keys.each do |configuration|
                  script.should.include <<-eos.strip_heredoc
        if [[ "$CONFIGURATION" == "#{configuration}" ]]; then
          install_framework "${BUILT_PRODUCTS_DIR}/BananaLib/BananaLib.framework"
        fi
                  eos
                end
              end

              it 'creates and adds launch screen storyboard for app target' do
                @watermelon_ios_pod_target.stubs(:build_type => BuildType.dynamic_framework)
                @ios_installer.install!
                app_target = @project.targets.find { |t| t.name == 'WatermelonLib-App' }
                launch_screen = app_target.resources_build_phase.files_references.find { |fr| fr.name == 'LaunchScreen.storyboard' }
                launch_screen.path.should.end_with 'Pods/WatermelonLib-App/LaunchScreen.storyboard'
                launch_screen.real_path.should.be.file
              end

              it 'does not add launch screen storyboard for app target when it is a spec resource' do
                @watermelon_ios_pod_target.stubs(:build_type => BuildType.dynamic_framework)
                path = Pathname('/tmp/Resources/LaunchScreen.storyboard')
                path.stubs(:realpath => path, :file? => true, :exist? => true)
                fr = @watermelon_ios_pod_target.file_accessors.find do |fa|
                  fa.spec.name == 'WatermelonLib/App'
                end
                fr.stubs(:resources => fr.resources + [path])
                @ios_installer.install!
                app_target = @project.targets.find { |t| t.name == 'WatermelonLib-App' }
                launch_screen = app_target.resources_build_phase.files_references.find { |f| f.name == 'LaunchScreen.storyboard' }
                launch_screen.should.be.nil # since it was not installed by the file references installer in the before block
              end

              it 'adds the resources bundles to the copy resources script for test target' do
                @ios_installer.install!
                script_path = @watermelon_ios_pod_target.copy_resources_script_path_for_spec(@watermelon_spec.test_specs.first)
                script = script_path.read
                @watermelon_ios_pod_target.user_build_configurations.keys.each do |configuration|
                  script.should.include <<-eos.strip_heredoc
        if [[ "$CONFIGURATION" == "#{configuration}" ]]; then
          install_resource "${PODS_ROOT}/../../spec/fixtures/watermelon-lib/App/resource.txt"
          install_resource "${PODS_CONFIGURATION_BUILD_DIR}/WatermelonLibTestResources.bundle"
        fi
                  eos
                end
              end

              it 'adds the resources to the copy resources phase for test target when a pod target is a static framework' do
                @watermelon_ios_pod_target.stubs(:build_type => BuildType.static_framework)
                @ios_installer.install!

                unit_test_target = @project.targets.find { |t| t.name == 'WatermelonLib-Unit-Tests' }

                resources = unit_test_target.resources_build_phase.files
                resources.count.should > 0
                resource = resources.find { |res| res.file_ref.path.include?('resource.txt') }
                resource.should.be.not.nil
              end

              it 'adds the resources bundles to the copy resources script for app target' do
                @ios_installer.install!
                script_path = @watermelon_ios_pod_target.copy_resources_script_path_for_spec(@watermelon_spec.app_specs.first)
                script = script_path.read
                @watermelon_ios_pod_target.user_build_configurations.keys.each do |configuration|
                  script.should.include <<-eos.strip_heredoc
        if [[ "$CONFIGURATION" == "#{configuration}" ]]; then
          install_resource "${PODS_CONFIGURATION_BUILD_DIR}/WatermelonLib/WatermelonLibExampleAppResources.bundle"
        fi
                  eos
                end
              end

              it 'allows pod target xcconfigs to override values normally set directly on the target' do
                @watermelon_ios_pod_target.root_spec.pod_target_xcconfig = { 'PRODUCT_MODULE_NAME' => 'FOOBAR' }
                @watermelon_ios_pod_target.test_specs.each { |s| s.pod_target_xcconfig = { 'PRODUCT_NAME' => 'FOOBAR_TEST' } }
                @ios_installer.install!

                library_target = @project.targets.find { |t| t.name == 'WatermelonLib' }
                library_target.build_configurations.map { |bc| bc.build_settings['PRODUCT_MODULE_NAME'] }.uniq.should == [nil]
                library_target.resolved_build_setting('PRODUCT_MODULE_NAME', true).values.uniq.should == %w(FOOBAR)

                unit_test_target = @project.targets.find { |t| t.name == 'WatermelonLib-Unit-Tests' }
                unit_test_target.build_configurations.map { |bc| bc.build_settings['PRODUCT_NAME'] }.uniq.should == [nil]
                unit_test_target.resolved_build_setting('PRODUCT_NAME', true).values.uniq.should == %w(FOOBAR_TEST)

                test_resource_bundle_target = @project.targets.find { |t| t.name == 'WatermelonLib-WatermelonLibTestResources' }
                test_resource_bundle_target.build_configurations.map { |bc| bc.build_settings['PRODUCT_NAME'] }.uniq.should == [nil]
                test_resource_bundle_target.resolved_build_setting('PRODUCT_NAME', true).values.uniq.should == %w(FOOBAR_TEST)

                test_resource_bundle_target = @project.targets.find { |t| t.name == 'WatermelonLib-WatermelonLibTestResources' }
                test_resource_bundle_target.build_configurations.map { |bc| bc.build_settings['PRODUCT_NAME'] }.uniq.should == [nil]
                test_resource_bundle_target.resolved_build_setting('PRODUCT_NAME', true).values.uniq.should == %w(FOOBAR_TEST)

                app_target = @project.targets.find { |t| t.name == 'WatermelonLib-App' }
                app_target.build_configurations.map { |bc| bc.build_settings['PRODUCT_NAME'] }.uniq.should == [nil]
                app_target.resolved_build_setting('PRODUCT_NAME', true).values.uniq.should == %w(ExampleApp)
              end

              it 'should not crash with nil build settings' do
                user_build_configurations = { 'MyConfig' => :myconfig }
                @watermelon_ios_pod_target = fixture_pod_target_with_specs([@watermelon_spec], BuildType.static_library,
                                                                           user_build_configurations, [],
                                                                           Platform.new(:ios, '6.0'),
                                                                           [@ios_target_definition])
                @ios_installer = PodTargetInstaller.new(config.sandbox, @project, @watermelon_ios_pod_target)
                @ios_installer.stubs(:create_xcconfig_file)

                @watermelon_ios_pod_target.root_spec.pod_target_xcconfig = { 'PRODUCT_MODULE_NAME' => 'FOOBAR' }
                @watermelon_ios_pod_target.build_settings[:release].should.nil?
                @watermelon_ios_pod_target.build_settings[:debug].should.nil?
                @ios_installer.install!
              end

              it 'adds swift compatibility header phase for swift static libraries' do
                @watermelon_ios_pod_target.stubs(:build_type => BuildType.static_library, :uses_swift? => true)

                @ios_installer.install!

                native_target = @project.targets.find { |t| t.name == @watermelon_ios_pod_target.label }
                compatibility_header_phase = native_target.build_phases.find { |ph| ph.display_name == 'Copy generated compatibility header' }
                compatibility_header_phase.shell_script.should == <<-'SH'.strip_heredoc
                  COMPATIBILITY_HEADER_PATH="${BUILT_PRODUCTS_DIR}/Swift Compatibility Header/${PRODUCT_MODULE_NAME}-Swift.h"
                  MODULE_MAP_PATH="${BUILT_PRODUCTS_DIR}/${PRODUCT_MODULE_NAME}.modulemap"

                  ditto "${DERIVED_SOURCES_DIR}/${PRODUCT_MODULE_NAME}-Swift.h" "${COMPATIBILITY_HEADER_PATH}"
                  ditto "${PODS_ROOT}/Headers/Public/WatermelonLib/WatermelonLib.modulemap" "${MODULE_MAP_PATH}"
                  ditto "${PODS_ROOT}/Headers/Public/WatermelonLib/WatermelonLib-umbrella.h" "${BUILT_PRODUCTS_DIR}"
                  printf "\n\nmodule ${PRODUCT_MODULE_NAME}.Swift {\n  header \"${COMPATIBILITY_HEADER_PATH}\"\n  requires objc\n}\n" >> "${MODULE_MAP_PATH}"
                SH
                compatibility_header_phase.input_paths.should == %w(${DERIVED_SOURCES_DIR}/${PRODUCT_MODULE_NAME}-Swift.h ${PODS_ROOT}/Headers/Public/WatermelonLib/WatermelonLib.modulemap ${PODS_ROOT}/Headers/Public/WatermelonLib/WatermelonLib-umbrella.h)
                compatibility_header_phase.output_paths.should == %w(${BUILT_PRODUCTS_DIR}/${PRODUCT_MODULE_NAME}.modulemap ${BUILT_PRODUCTS_DIR}/WatermelonLib-umbrella.h ${BUILT_PRODUCTS_DIR}/Swift\ Compatibility\ Header/${PRODUCT_MODULE_NAME}-Swift.h)
              end

              it 'does not add swift compatibility header phase for swift static frameworks' do
                @watermelon_ios_pod_target.stubs(:build_type => BuildType.static_framework, :uses_swift? => true)

                @ios_installer.install!

                native_target = @project.targets.find { |t| t.name == @watermelon_ios_pod_target.label }
                compatibility_header_phase = native_target.build_phases.find { |ph| ph.display_name == 'Copy generated compatibility header' }
                compatibility_header_phase.should.be.nil
              end

              it 'raises for swift static libraries with custom module maps' do
                @watermelon_ios_pod_target.stubs(:build_type => BuildType.static_library, :uses_swift? => true)
                @ios_installer.stubs(:custom_module_map => mock('custom_module_map', :read => ''))

                e = ->() { @ios_installer.install! }.should.raise(Informative)
                e.message.should.include '[!] Using Swift static libraries with custom module maps is currently not supported. Please build `WatermelonLib` as a framework or remove the custom module map.'
              end
            end

            describe 'test other files under sources' do
              before do
                @minions_spec = fixture_spec('minions-lib/MinionsLib.podspec')
                @target_definition = fixture_target_definition('SampleProject')
                @project = Project.new(config.sandbox.project_path)
                @project.add_pod_group('MinionsLib', fixture('minions-lib'))
                @minions_pod_target = fixture_pod_target_with_specs([@minions_spec, *@minions_spec.recursive_subspecs],
                                                                    BuildType.static_library,
                                                                    { 'Debug' => :debug, 'Release' => :release }, [],
                                                                    Platform.ios, [@target_definition])
                FileReferencesInstaller.new(config.sandbox, [@minions_pod_target], @project).install!
                @installer = PodTargetInstaller.new(config.sandbox, @project, @minions_pod_target)
              end

              it 'raises when references are missing for non-source files' do
                @minions_pod_target.stubs(:build_type).returns(BuildType.dynamic_framework)
                exception = lambda { @installer.install! }.should.raise Informative
                exception.message.should.include 'Unable to find other source ref for `Contents.json` for target `MinionsLib`.'
              end
            end

            #--------------------------------------#

            it 'adds the source files of each pod to the target of the Pod library' do
              names = @installer.install!.native_target.source_build_phase.files.map { |bf| bf.file_ref.display_name }
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
                file_path = @first_source_file.dirname + "notthere-#{@first_source_file.basename}"
                File.symlink(file_path, @source_symlink_file)
                path_list = Sandbox::PathList.new(fixture('banana-lib'))
                file_accessor = Sandbox::FileAccessor.new(path_list, @banana_spec.consumer(:ios))
                @pod_target.stubs(:file_accessors).returns([file_accessor])
                exception = lambda { @installer.install! }.should.raise Informative
                exception.message.should.include 'Unable to find source ref for `SymLinkOf-Banana.m` for target `BananaLib`.'
              end

              it 'raises when header file reference is not found' do
                file_path = @first_header_file.dirname + "notthere-#{@first_header_file.basename}"
                File.symlink(file_path, @header_symlink_file)
                path_list = Sandbox::PathList.new(fixture('banana-lib'))
                file_accessor = Sandbox::FileAccessor.new(path_list, @banana_spec.consumer(:ios))
                @pod_target.stubs(:file_accessors).returns([file_accessor])
                exception = lambda { @installer.install! }.should.raise Informative
                exception.message.should.include 'Unable to find header ref for `SymLinkOf-Banana.h` for target `BananaLib`.'
              end

              it 'does not raise when header file reference is found' do
                File.symlink(@first_header_file, @header_symlink_file)
                path_list = Sandbox::PathList.new(fixture('banana-lib'))
                file_accessor = Sandbox::FileAccessor.new(path_list, @banana_spec.consumer(:ios))
                @pod_target.stubs(:file_accessors).returns([file_accessor])
                group = @project.group_for_spec('BananaLib')
                @project.add_file_reference(@header_symlink_file.to_s, group)
                lambda { @installer.install! }.should.not.raise
              end

              it 'does not raise when source file reference is found' do
                File.symlink(@first_source_file, @source_symlink_file)
                path_list = Sandbox::PathList.new(fixture('banana-lib'))
                file_accessor = Sandbox::FileAccessor.new(path_list, @banana_spec.consumer(:ios))
                @pod_target.stubs(:file_accessors).returns([file_accessor])
                group = @project.group_for_spec('BananaLib')
                @project.add_file_reference(@source_symlink_file.to_s, group)
                lambda { @installer.install! }.should.not.raise
              end
            end

            #--------------------------------------#

            it 'adds framework resources to the framework target' do
              @pod_target.stubs(:build_type => BuildType.dynamic_framework)
              @installer.install!
              resources = @project.targets.first.resources_build_phase.files
              resources.count.should > 0
              resource = resources.find { |res| res.file_ref.path.include?('logo-sidebar.png') }
              resource.should.be.not.nil

              resource = resources.find { |res| res.file_ref.path.include?('en.lproj') }
              resource.should.be.not.nil
            end

            it 'adds compilable framework resources to the static framework target' do
              @pod_target.stubs(:build_type => BuildType.static_framework)
              @installer.install!
              resources = @project.targets.first.resources_build_phase.files
              resources.count.should > 0
              resource = resources.find { |res| res.file_ref.path.include?('Migration.xcmappingmodel') }
              resource.should.be.not.nil
            end

            it 'doesn\'t add non-compilable framework resources to the static framework target' do
              @pod_target.stubs(:build_type => BuildType.static_framework)
              @installer.install!
              resources = @project.targets.first.resources_build_phase.files
              resources.count.should > 0
              resource = resources.find { |res| res.file_ref.path.include?('logo-sidebar.png') }
              resource.should.be.nil

              resource = resources.find { |res| res.file_ref.path.include?('en.lproj') }
              resource.should.be.nil
            end

            it 'doesn\'t add xcassets resources to the static framework target' do
              @pod_target.stubs(:build_type => BuildType.static_framework)
              @installer.install!
              resources = @project.targets.first.resources_build_phase.files
              resources.count.should > 0
              resource = resources.find { |res| res.file_ref.path.include?('Images.xcassets') }
              resource.should.be.nil
            end

            it 'adds xcassets resources to the dynamic framework target' do
              @pod_target.stubs(:build_type => BuildType.dynamic_framework)
              @installer.install!
              resources = @project.targets.first.resources_build_phase.files
              resources.count.should > 0
              resource = resources.find { |res| res.file_ref.path.include?('Images.xcassets') }
              resource.should.be.not.nil
            end

            it 'includes spec info_plist entries for dynamic frameworks' do
              @pod_target.stubs(:build_type => BuildType.dynamic_framework)
              expected_entries = {
                'SOME_VAR' => 'SOME_VALUE',
              }
              @banana_spec.info_plist = expected_entries
              @installer.expects(:create_info_plist_file_with_sandbox).
                with do |sandbox, _, _, version, platform, bundle_type, other_args|
                sandbox.should == config.sandbox
                version.should == '1.0.0'
                platform.should == :ios
                bundle_type.should == :fmwk
                other_args[:additional_entries].should == expected_entries
              end
              @installer.install!
            end

            it 'includes spec info_plist entries for static frameworks' do
              @pod_target.stubs(:build_type => BuildType.static_framework)
              expected_entries = {
                'SOME_VAR' => 'SOME_VALUE',
              }
              @banana_spec.info_plist = expected_entries
              @installer.expects(:create_info_plist_file_with_sandbox).
                with do |sandbox, _, _, version, platform, bundle_type, other_args|
                sandbox.should == config.sandbox
                version.should == '1.0.0'
                platform.should == :ios
                bundle_type.should == :fmwk
                other_args[:additional_entries].should == expected_entries
              end
              @installer.install!
            end

            #--------------------------------------#

            describe 'with a scoped pod target' do
              before do
                @pod_target = @pod_target.scoped.first
                @installer = PodTargetInstaller.new(config.sandbox, @project, @pod_target)
              end

              it 'adds file references for the support files of the target' do
                @installer.install!
                group = @project['Pods/BananaLib/Support Files']
                group.children.map(&:display_name).sort.should == [
                  'BananaLib-Pods-SampleProject-dummy.m',
                  'BananaLib-Pods-SampleProject-prefix.pch',
                  'BananaLib-Pods-SampleProject.debug.xcconfig',
                  'BananaLib-Pods-SampleProject.release.xcconfig',
                ]
              end

              it 'verifies keeping prefix header generation' do
                @pod_target.specs.first.stubs(:prefix_header_file).returns(true)
                @installer.install!
                group = @project['Pods/BananaLib/Support Files']
                group.children.map(&:display_name).sort.should == [
                  'BananaLib-Pods-SampleProject-dummy.m',
                  'BananaLib-Pods-SampleProject-prefix.pch',
                  'BananaLib-Pods-SampleProject.debug.xcconfig',
                  'BananaLib-Pods-SampleProject.release.xcconfig',
                ]
              end

              it 'verifies disabling prefix header generation' do
                @pod_target.specs.first.stubs(:prefix_header_file).returns(false)
                @installer.install!
                group = @project['Pods/BananaLib/Support Files']
                group.children.map(&:display_name).sort.should == [
                  'BananaLib-Pods-SampleProject-dummy.m',
                  'BananaLib-Pods-SampleProject.debug.xcconfig',
                  'BananaLib-Pods-SampleProject.release.xcconfig',
                ]
              end

              it 'verifies keeping prefix header generation for subspecs' do
                @project = Project.new(config.sandbox.project_path)
                @project.add_pod_group('HeadersMappingSubspec', fixture('HeadersMappingSubspec'))
                @pod_spec = fixture_spec('HeadersMappingSubspec/HeadersMappingSubspec.podspec')
                @pod_target = fixture_pod_target_with_specs([@pod_spec, *@pod_spec.subspecs], BuildType.dynamic_framework,
                                                            { 'Debug' => :debug, 'Release' => :release }, [],
                                                            Pod::Platform.new(:ios, '6.0'), [@target_definition], nil)
                FileReferencesInstaller.new(config.sandbox, [@pod_target], @project).install!
                @installer = PodTargetInstaller.new(config.sandbox, @project, @pod_target)
                @installer.install!
                group = @project['Pods/HeadersMappingSubspec/Support Files']
                group.children.map(&:display_name).sort.should == [
                  'HeadersMappingSubspec-Info.plist',
                  'HeadersMappingSubspec-dummy.m',
                  'HeadersMappingSubspec-prefix.pch',
                  'HeadersMappingSubspec.debug.xcconfig',
                  'HeadersMappingSubspec.modulemap',
                  'HeadersMappingSubspec.release.xcconfig',
                ]
              end

              it 'verifies skipping prefix header generation for subspecs' do
                @project = Project.new(config.sandbox.project_path)
                @project.add_pod_group('HeadersMappingSubspec', fixture('HeadersMappingSubspec'))
                @pod_spec = fixture_spec('HeadersMappingSubspec/HeadersMappingSubspec.podspec')
                @pod_target = fixture_pod_target_with_specs([@pod_spec, *@pod_spec.subspecs], BuildType.dynamic_framework,
                                                            { 'Debug' => :debug, 'Release' => :release }, [],
                                                            Pod::Platform.new(:ios, '6.0'), [@target_definition], nil)
                @pod_spec.stubs(:prefix_header_file).returns(false)
                FileReferencesInstaller.new(config.sandbox, [@pod_target], @project).install!
                @installer = PodTargetInstaller.new(config.sandbox, @project, @pod_target)
                @installer.install!
                group = @project['Pods/HeadersMappingSubspec/Support Files']
                group.children.map(&:display_name).sort.should == [
                  'HeadersMappingSubspec-Info.plist',
                  'HeadersMappingSubspec-dummy.m',
                  'HeadersMappingSubspec.debug.xcconfig',
                  'HeadersMappingSubspec.modulemap',
                  'HeadersMappingSubspec.release.xcconfig',
                ]
              end

              it 'adds the module map when the target defines a module' do
                @pod_target.stubs(:defines_module?).returns(true)
                @installer.install!
                group = @project['Pods/BananaLib/Support Files']
                group.children.map(&:display_name).sort.should == [
                  'BananaLib-Pods-SampleProject-dummy.m',
                  'BananaLib-Pods-SampleProject-prefix.pch',
                  'BananaLib-Pods-SampleProject.debug.xcconfig',
                  'BananaLib-Pods-SampleProject.modulemap',
                  'BananaLib-Pods-SampleProject.release.xcconfig',
                ]
              end

              it 'adds the target for the static library to the project' do
                @installer.install!
                @project.targets.count.should == 1
                @project.targets.first.name.should == 'BananaLib-Pods-SampleProject'
              end

              describe 'resource bundle targets' do
                before do
                  @banana_spec.resource_bundles = { 'banana_bundle' => ['Resources/**/*'] }
                end
                it 'adds the resource bundle targets' do
                  @installer.install!
                  @bundle_target = @project.targets.find { |t| t.name == 'BananaLib-Pods-SampleProject-banana_bundle' }
                  @bundle_target.should.be.an.instance_of Xcodeproj::Project::Object::PBXNativeTarget
                  @bundle_target.product_reference.name.should == 'BananaLib-Pods-SampleProject-banana_bundle'
                  @bundle_target.product_reference.path.should == 'banana_bundle.bundle'
                  @bundle_target.platform_name.should == :ios
                  @bundle_target.deployment_target.should == '4.3'
                end

                it 'adds the build configurations to the resources bundle targets' do
                  @installer.install!
                  @bundle_target = @project.targets.find { |t| t.name == 'BananaLib-Pods-SampleProject-banana_bundle' }
                  @bundle_target.build_configurations.each do |bc|
                    file = config.sandbox.root + @pod_target.xcconfig_path(bc.name.downcase)
                    bc.base_configuration_reference.real_path.should == file
                  end
                end

                it 'sets the correct product name' do
                  @installer.install!
                  @bundle_target = @project.targets.find { |t| t.name == 'BananaLib-Pods-SampleProject-banana_bundle' }
                  @bundle_target.build_configurations.each do |bc|
                    bc.build_settings['PRODUCT_NAME'].should == 'banana_bundle'
                  end
                end

                it 'sets the correct Info.plist file path' do
                  @installer.install!
                  @bundle_target = @project.targets.find { |t| t.name == 'BananaLib-Pods-SampleProject-banana_bundle' }
                  @bundle_target.build_configurations.each do |bc|
                    bc.build_settings['INFOPLIST_FILE'].should == 'Target Support Files/BananaLib-Pods-SampleProject/ResourceBundle-banana_bundle-BananaLib-Pods-SampleProject-Info.plist'
                  end
                end

                it 'sets the correct build dir' do
                  @installer.install!
                  @bundle_target = @project.targets.find { |t| t.name == 'BananaLib-Pods-SampleProject-banana_bundle' }
                  @bundle_target.build_configurations.each do |bc|
                    bc.build_settings['CONFIGURATION_BUILD_DIR'].should == '$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)/BananaLib-Pods-SampleProject'
                  end
                end

                it 'sets the correct targeted device family for the resource bundle targets' do
                  @installer.install!
                  @bundle_target = @project.targets.find { |t| t.name == 'BananaLib-Pods-SampleProject-banana_bundle' }
                  @bundle_target.build_configurations.each do |bc|
                    bc.build_settings['TARGETED_DEVICE_FAMILY'].should == '1,2'
                  end
                end

                it 'sets the correct default module for storyboards in resource bundle targets' do
                  @installer.install!
                  @bundle_target = @project.targets.find { |t| t.name == 'BananaLib-Pods-SampleProject-banana_bundle' }
                  @bundle_target.build_configurations.each do |bc|
                    bc.build_settings['IBSC_MODULE'].should == 'BananaLib'
                  end
                end

                it 'sets the Swift version build setting when resources bundle contains sources and target has Swift' do
                  @banana_spec.resource_bundles = { 'banana_bundle' => ['Resources/**/*'] }
                  @banana_spec.module_map = nil
                  @pod_target.stubs(:uses_swift?).returns(true)
                  @pod_target.stubs(:uses_swift_for_spec?).returns(true)
                  @pod_target.stubs(:swift_version).returns('3.2')
                  @installer.install!
                  @bundle_target = @project.targets.find { |t| t.name == 'BananaLib-Pods-SampleProject-banana_bundle' }
                  @bundle_target.build_configurations.each do |bc|
                    bc.build_settings['SWIFT_VERSION'].should == '3.2'
                  end
                end

                it 'does not set the Swift version build setting when resources bundle does not contain sources and target has Swift' do
                  @banana_spec.resource_bundles = { 'banana_bundle' => ['Resources/**/*.png'] }
                  @banana_spec.module_map = nil
                  @pod_target.stubs(:uses_swift?).returns(true)
                  @pod_target.stubs(:uses_swift_for_spec?).returns(true)
                  @pod_target.stubs(:swift_version).returns('4.2')
                  @installer.install!
                  @bundle_target = @project.targets.find { |t| t.name == 'BananaLib-Pods-SampleProject-banana_bundle' }
                  @bundle_target.build_configurations.each do |bc|
                    bc.build_settings['SWIFT_VERSION'].should.be.nil
                  end
                end
              end
            end

            #--------------------------------------#

            describe 'with an unscoped pod target' do
              it 'adds file references for the support files of the target' do
                @installer.install!
                group = @project['Pods/BananaLib/Support Files']
                group.children.map(&:display_name).sort.should == [
                  'BananaLib-dummy.m',
                  'BananaLib-prefix.pch',
                  'BananaLib.debug.xcconfig',
                  'BananaLib.release.xcconfig',
                ]
              end

              it 'verifies disabling prefix header generation' do
                @pod_target.specs.first.stubs(:prefix_header_file).returns(false)
                @installer.install!
                group = @project['Pods/BananaLib/Support Files']
                group.children.map(&:display_name).sort.should == [
                  'BananaLib-dummy.m',
                  'BananaLib.debug.xcconfig',
                  'BananaLib.release.xcconfig',
                ]
              end

              it 'adds the module map when the target defines a module' do
                @pod_target.stubs(:defines_module?).returns(true)
                @installer.install!
                group = @project['Pods/BananaLib/Support Files']
                group.children.map(&:display_name).sort.should == [
                  'BananaLib-dummy.m',
                  'BananaLib-prefix.pch',
                  'BananaLib.debug.xcconfig',
                  'BananaLib.modulemap',
                  'BananaLib.release.xcconfig',
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
                end

                it 'adds the resource bundle targets' do
                  @installer.install!
                  @bundle_target = @project.targets.find { |t| t.name == 'BananaLib-banana_bundle' }
                  @bundle_target.should.be.an.instance_of Xcodeproj::Project::Object::PBXNativeTarget
                  @bundle_target.product_reference.name.should == 'BananaLib-banana_bundle'
                  @bundle_target.product_reference.path.should == 'banana_bundle.bundle'
                end

                it 'adds the build configurations to the resources bundle targets' do
                  @installer.install!
                  @bundle_target = @project.targets.find { |t| t.name == 'BananaLib-banana_bundle' }
                  @bundle_target.build_configurations.each do |bc|
                    file = config.sandbox.root + @pod_target.xcconfig_path(bc.name.downcase)
                    bc.base_configuration_reference.real_path.should == file
                  end
                end

                it 'uses the deployment target specified by a non library spec' do
                  watermelon_spec = fixture_spec('watermelon-lib/WatermelonLib.podspec')
                  project = Project.new(config.sandbox.project_path)
                  project.add_pod_group('WatermelonLib', fixture('watermelon-lib'))
                  target_definition = fixture_target_definition('SampleProject', Platform.new(:ios, '6.0'))
                  user_build_configurations = { 'Debug' => :debug, 'Release' => :release }
                  all_specs = [watermelon_spec, *watermelon_spec.recursive_subspecs]
                  test_spec = all_specs.find { |s| s.name == 'WatermelonLib/Tests' }
                  test_spec.ios.deployment_target = '12.0'
                  watermelon_pod_target = fixture_pod_target_with_specs(all_specs, BuildType.static_library,
                                                                        user_build_configurations, [],
                                                                        Platform.new(:ios, '6.0'), [target_definition])
                  FileReferencesInstaller.new(config.sandbox, [watermelon_pod_target], project).install!
                  PodTargetInstaller.new(config.sandbox, project, watermelon_pod_target).install!
                  test_resource_bundle = project.targets.find { |t| t.name == 'WatermelonLib-Unit-Tests' }
                  test_resource_bundle.build_configurations.each do |bc|
                    bc.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].should == '12.0'
                  end
                end
              end
            end

            #--------------------------------------#

            it 'creates the xcconfig file' do
              @installer.install!
              %w(debug release).each do |variant|
                file = config.sandbox.root + @pod_target.xcconfig_path(variant)
                xcconfig = Xcodeproj::Config.new(file)
                xcconfig.to_hash['PODS_ROOT'].should == '${SRCROOT}'
              end
            end

            it "creates a prefix header, including the contents of the specification's prefix header" do
              @banana_spec.prefix_header_contents = '#import "BlocksKit.h"'
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
              dummy_source_basename = @pod_target.dummy_source_path.basename.to_s
              build_files = @installer.install!.native_target.source_build_phase.files
              build_file = build_files.find { |bf| bf.file_ref.display_name == dummy_source_basename }
              build_file.should.be.not.nil
              build_file.file_ref.path.should == dummy_source_basename
              @pod_target.dummy_source_path.read.should.include?('@interface PodsDummy_BananaLib')
            end

            it 'creates an info.plist file when frameworks are required' do
              @pod_target.stubs(:build_type).returns(BuildType.dynamic_framework)
              @installer.install!
              group = @project['Pods/BananaLib/Support Files']
              group.children.map(&:display_name).sort.should == [
                'BananaLib-Info.plist',
                'BananaLib-dummy.m',
                'BananaLib-prefix.pch',
                'BananaLib.debug.xcconfig',
                'BananaLib.modulemap',
                'BananaLib.release.xcconfig',
              ]
            end

            it 'creates an info.plist file when static frameworks are required' do
              @pod_target.stubs(:build_type).returns(BuildType.static_framework)
              @installer.install!
              group = @project['Pods/BananaLib/Support Files']
              group.children.map(&:display_name).sort.should == [
                'BananaLib-Info.plist',
                'BananaLib-dummy.m',
                'BananaLib-prefix.pch',
                'BananaLib.debug.xcconfig',
                'BananaLib.modulemap',
                'BananaLib.release.xcconfig',
              ]
            end

            it 'does not create an Info.plist file if INFOPLIST_FILE is set' do
              @pod_target.stubs(:build_type).returns(BuildType.dynamic_framework)
              @banana_spec.pod_target_xcconfig = {
                'INFOPLIST_FILE' => 'somefile.plist',
              }
              @installer.install!
              group = @project['Pods/BananaLib/Support Files']
              group.children.map(&:display_name).sort.should == [
                'BananaLib-dummy.m',
                'BananaLib-prefix.pch',
                'BananaLib.debug.xcconfig',
                'BananaLib.modulemap',
                'BananaLib.release.xcconfig',
              ]
            end

            #--------------------------------------------------------------------------------#

            it 'creates an aggregate placeholder native target if the target should not be built' do
              @pod_target.stubs(:should_build?).returns(false)
              @installer.install!
              @project.targets.map(&:name).should == ['BananaLib']
              @project.targets.first.class.should == Xcodeproj::Project::PBXAggregateTarget
              @project.targets.first.build_configurations.each do |config|
                config.build_settings['SDKROOT'].should == 'iphoneos'
              end
            end

            it 'adds xcconfig file reference for the aggregate placeholder native target' do
              @pod_target.stubs(:should_build?).returns(false)
              @installer.install!
              group = @project['Pods/BananaLib/Support Files']
              group.children.map(&:display_name).sort.should == %w(BananaLib.debug.xcconfig BananaLib.release.xcconfig)
            end

            it 'does not set architectures for targets that should not build' do
              @pod_target.stubs(:should_build?).returns(false)
              result = @installer.install!
              target = result.native_target
              target.build_configurations.each do |config|
                config.build_settings['ARCHS'].should.be.nil
              end
            end

            #--------------------------------------------------------------------------------#

            describe '#create_module_map' do
              it 'uses relative paths when linking umbrella headers' do
                @installer.stubs(:update_changed_file)
                @installer.stubs(:add_file_to_support_group)
                write_path = Pathname.new('/Pods/Target Support Files/MyPod/MyPod.modulemap')
                target_module_path = Pathname.new('/Pods/Headers/Public/MyPod/MyPod.modulemap')
                relative_path = Pathname.new('../../../Target Support Files/MyPod/MyPod.modulemap')

                @pod_target.stubs(:module_map_path_to_write).returns(write_path)
                @pod_target.stubs(:module_map_path).returns(target_module_path)
                custom_module_map = mock(:read => '')
                @installer.stubs(:custom_module_map).returns(custom_module_map)
                Pathname.any_instance.stubs(:mkpath)

                FileUtils.expects(:ln_sf).with(relative_path, target_module_path)
                native_target = mock(:build_configurations => [])
                @installer.send(:create_module_map, native_target)
              end
            end

            #--------------------------------------------------------------------------------#

            describe 'concerning header_mappings_dirs' do
              before do
                @project = Project.new(config.sandbox.project_path)
                @project.add_pod_group('snake', fixture('snake'))

                @pod_target = fixture_pod_target('snake/snake.podspec', BuildType.dynamic_framework,
                                                 { 'Debug' => :debug, 'Release' => :release }, [],
                                                 Pod::Platform.new(:ios, '6.0'), [@target_definition], nil)

                FileReferencesInstaller.new(config.sandbox, [@pod_target], @project).install!
                @installer = PodTargetInstaller.new(config.sandbox, @project, @pod_target)
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

                target.build_phases.map(&:display_name).should == [
                  'Headers',
                  'Copy A Public Headers',
                  'Copy . Public Headers',
                  'Copy B Private Headers',
                  'Sources',
                  'Frameworks',
                  'Resources',
                ]

                copy_files_build_phases = target.copy_files_build_phases.sort_by(&:name)
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

              it 'verifies that headers in build phase for static libraries are all Project headers' do
                @pod_target.stubs(:build_type).returns(BuildType.static_library)

                @installer.install!

                @project.targets.first.headers_build_phase.files.find do |hf|
                  hf.settings['ATTRIBUTES'].should == ['Project']
                end
              end
            end

            describe 'concerning header_mappings_dirs in subspecs' do
              before do
                @project = Project.new(config.sandbox.project_path)
                @project.add_pod_group('HeadersMappingSubspec', fixture('HeadersMappingSubspec'))
                @pod_spec = fixture_spec('HeadersMappingSubspec/HeadersMappingSubspec.podspec')
              end

              describe 'depending on the root' do
                before do
                  @pod_target = fixture_pod_target_with_specs([@pod_spec, *@pod_spec.subspecs], BuildType.dynamic_framework,
                                                              { 'Debug' => :debug, 'Release' => :release }, [],
                                                              Pod::Platform.new(:ios, '6.0'), [@target_definition], nil)
                  FileReferencesInstaller.new(config.sandbox, [@pod_target], @project).install!
                  @installer = PodTargetInstaller.new(config.sandbox, @project, @pod_target)
                end

                it 'creates custom copy files phases for framework pods' do
                  @installer.install!

                  target = @project.native_targets.first
                  target.name.should == 'HeadersMappingSubspec'

                  header_build_phase_file_refs = target.headers_build_phase.files.
                    reject { |build_file| build_file.settings.nil? }.
                    map { |build_file| build_file.file_ref.path }
                  header_build_phase_file_refs.should == [
                    'root.h',
                  ]
                  copy_files_build_phases = target.copy_files_build_phases.sort_by(&:name)
                  copy_files_build_phases.map(&:name).should == [
                    'Copy . Public Headers',
                    'Copy external/magic Private Headers',
                  ]

                  copy_files_build_phases.map(&:symbol_dst_subfolder_spec).should == Array.new(2, :products_directory)

                  copy_files_build_phases.map(&:dst_path).should == [
                    '$(PUBLIC_HEADERS_FOLDER_PATH)/.',
                    '$(PRIVATE_HEADERS_FOLDER_PATH)/external/magic',
                  ]

                  copy_files_build_phases.map { |phase| phase.files_references.map(&:path) }.should == [
                    ['include/mapping/all.h', 'include/mapping/umbrella.h'],
                    ['external/magic/beans.h'],
                  ]
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

                it 'verifies that headers in build phase for static libraries are all Project headers' do
                  @pod_target.stubs(:build_type).returns(BuildType.static_library)

                  @installer.install!

                  @project.targets.first.headers_build_phase.files.find do |hf|
                    hf.settings['ATTRIBUTES'].should == ['Project']
                  end
                end
              end

              describe 'depending on a subspec' do
                before do
                  @project.group_for_spec('HeadersMappingSubspec')
                  @pod_spec.subspecs.last.name.should == 'HeadersMappingSubspec/Implementation'
                  @pod_target = fixture_pod_target_with_specs(@pod_spec.subspecs.reverse, BuildType.dynamic_framework,
                                                              { 'Debug' => :debug, 'Release' => :release }, [],
                                                              Pod::Platform.new(:ios, '6.0'), [@target_definition], nil)

                  FileReferencesInstaller.new(config.sandbox, [@pod_target], @project).install!
                  @installer = PodTargetInstaller.new(config.sandbox, @project, @pod_target)
                end

                it 'creates custom copy files phases for framework pods' do
                  @installer.install!

                  target = @project.native_targets.first
                  target.name.should == 'HeadersMappingSubspec'

                  header_build_phase_file_refs = target.headers_build_phase.files.
                    reject { |build_file| build_file.settings.nil? }.
                    map { |build_file| build_file.file_ref.path }
                  header_build_phase_file_refs.should.be.empty

                  copy_files_build_phases = target.copy_files_build_phases.sort_by(&:name)
                  copy_files_build_phases.map(&:name).should == [
                    'Copy . Public Headers',
                    'Copy external/magic Private Headers',
                  ]

                  copy_files_build_phases.map(&:symbol_dst_subfolder_spec).should == Array.new(2, :products_directory)

                  copy_files_build_phases.map(&:dst_path).should == [
                    '$(PUBLIC_HEADERS_FOLDER_PATH)/.',
                    '$(PRIVATE_HEADERS_FOLDER_PATH)/external/magic',
                  ]

                  copy_files_build_phases.map { |phase| phase.files_references.map(&:path) }.should == [
                    ['include/mapping/all.h', 'include/mapping/umbrella.h'],
                    ['external/magic/beans.h'],
                  ]
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

                it 'verifies that headers in build phase for static libraries are all Project headers' do
                  @pod_target.stubs(:build_type).returns(BuildType.static_library)

                  @installer.install!

                  @project.targets.first.headers_build_phase.files.find do |hf|
                    hf.settings['ATTRIBUTES'].should == ['Project']
                  end
                end
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
                dtrace_files = @installer.install!.native_target.source_build_phase.files.select do |sf|
                  File.extname(sf.file_ref.path) == '.d'
                end
                dtrace_files.each do |dt|
                  dt.settings.should.be.nil
                end
              end

              it 'adds -w per pod if target definition inhibits warnings for that pod' do
                @installer.target.target_definitions.first.stubs(:inhibits_warnings_for_pod?).returns(true)
                flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios), true, :objc)
                flags.should.include?('-w')
              end

              it "doesn't inhibit warnings by default" do
                flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios), true, :objc)
                flags.should.not.include?('-w')
              end

              it 'adds -Xanalyzer -analyzer-disable-checker per pod for objc language' do
                @installer.target.target_definitions.first.stubs(:inhibits_warnings_for_pod?).returns(true)
                flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios), true, :objc)

                flags.should.include?('-Xanalyzer -analyzer-disable-all-checks')
              end

              it "doesn't inhibit analyzer warnings by default for objc language" do
                flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios), true, :objc)
                flags.should.not.include?('-Xanalyzer -analyzer-disable-all-checks')
              end

              it "doesn't inhibit analyzer warnings for Swift language" do
                flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios), true, :swift)
                flags.should.not.include?('-Xanalyzer -analyzer-disable-all-checks')
              end

              describe 'concerning ARC before and after iOS 6.0 and OS X 10.8' do
                it 'does not do anything if ARC is *not* required' do
                  @spec.ios.deployment_target = '5'
                  @spec.osx.deployment_target = '10.6'
                  ios_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios), false, :objc)
                  osx_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:osx), false, :objc)
                  ios_flags.should.not.include '-DOS_OBJECT_USE_OBJC'
                  osx_flags.should.not.include '-DOS_OBJECT_USE_OBJC'
                end

                it 'does *not* disable the `OS_OBJECT_USE_OBJC` flag if ARC is required and has a deployment target of >= iOS 6.0 or OS X 10.8' do
                  @spec.ios.deployment_target = '6'
                  @spec.osx.deployment_target = '10.8'
                  ios_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios), false, :objc)
                  osx_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:osx), false, :objc)
                  ios_flags.should.not.include '-DOS_OBJECT_USE_OBJC'
                  osx_flags.should.not.include '-DOS_OBJECT_USE_OBJC'
                end

                it '*does* disable the `OS_OBJECT_USE_OBJC` flag if ARC is required but has a deployment target < iOS 6.0 or OS X 10.8' do
                  @spec.ios.deployment_target = '5.1'
                  @spec.osx.deployment_target = '10.7.2'
                  ios_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios), true, :objc)
                  osx_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:osx), true, :objc)
                  ios_flags.should.include '-DOS_OBJECT_USE_OBJC'
                  osx_flags.should.include '-DOS_OBJECT_USE_OBJC'
                end

                it '*does* disable the `OS_OBJECT_USE_OBJC` flag if ARC is required and *no* deployment target is specified' do
                  ios_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios), true, :objc)
                  osx_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:osx), true, :objc)
                  ios_flags.should.include '-DOS_OBJECT_USE_OBJC'
                  osx_flags.should.include '-DOS_OBJECT_USE_OBJC'
                end

                it 'does not include -fno-objc-arc for Swift compiler flags.' do
                  ios_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:ios), true, :swift)
                  osx_flags = @installer.send(:compiler_flags_for_consumer, @spec.consumer(:osx), true, :swift)
                  ios_flags.should.not.include '-fno-objc-arc'
                  osx_flags.should.not.include '-fno-objc-arc'
                end
              end
            end

            describe 'concerning resources' do
              before do
                @project = Project.new(config.sandbox.project_path)

                @banana_spec = fixture_spec('banana-lib/BananaLib.podspec')
                @banana_spec.resources = ['Resources/**/*']
                @banana_spec.resource_bundle = nil
                @project.add_pod_group('BananaLib', fixture('banana-lib'))

                @pod_target = fixture_pod_target(@banana_spec, BuildType.dynamic_framework, 'Debug' => :debug, 'Release' => :release)
                target_installer = PodTargetInstaller.new(config.sandbox, @project, @pod_target)

                # Use a file references installer to add the files so that the correct ones are added.
                file_ref_installer = Installer::Xcode::PodsProjectGenerator::FileReferencesInstaller.new(config.sandbox,
                                                                                                         [@pod_target],
                                                                                                         @project)
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

                # The data model should be in the compile sources phase.
                core_data_sources_file = native_target.source_build_phase.files.find do |bf|
                  bf.file_ref.path == 'Resources/Sample.xcdatamodeld'
                end
                core_data_sources_file.should.be.not.nil
              end

              it 'adds RealityComposer projects to the compile sources phase (non-bundles only)' do
                native_target = @project.targets.first

                # The project should not be in the resources phase.
                reality_composer_resources_file = native_target.resources_build_phase.files.find do |bf|
                  bf.file_ref.path == 'Resources/Sample.rcproject'
                end
                reality_composer_resources_file.should.be.nil

                # The project should not be in the resources phase.
                reality_composer_sources_file = native_target.source_build_phase.files.find do |bf|
                  bf.file_ref.path == 'Resources/Sample.rcproject'
                end
                reality_composer_sources_file.should.be.not.nil
              end
            end

            describe 'concerning resource bundles' do
              before do
                @project = Project.new(config.sandbox.project_path)

                @banana_spec = fixture_spec('banana-lib/BananaLib.podspec')
                @banana_spec.resources = nil
                @banana_spec.resource_bundle = { 'banana_bundle' => ['Resources/**/*'] }
                @project.add_pod_group('BananaLib', fixture('banana-lib'))

                @pod_target = fixture_pod_target(@banana_spec, BuildType.static_library, 'Debug' => :debug, 'Release' => :release)
                target_installer = PodTargetInstaller.new(config.sandbox, @project, @pod_target)

                # Use a file references installer to add the files so that the correct ones are added.
                file_ref_installer = Installer::Xcode::PodsProjectGenerator::FileReferencesInstaller.new(config.sandbox,
                                                                                                         [@pod_target],
                                                                                                         @project)
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
                dir_build_file = @bundle_target.resources_build_phase.files.find do |bf|
                  bf.file_ref.path == 'Resources/Sample.xcdatamodeld'
                end
                dir_build_file.should.be.not.nil

                # An item within the model directory should not be present.
                version_build_file = @bundle_target.resources_build_phase.files.find do |bf|
                  bf.file_ref.path =~ %r{Resources/Sample.xcdatamodeld/Sample.xcdatamodel}i
                end
                version_build_file.should.be.nil
              end

              it 'adds Core Data migration mapping models directly to resources' do
                # The model directory item should be present.
                dir_build_file = @bundle_target.resources_build_phase.files.find do |bf|
                  bf.file_ref.path == 'Resources/Migration.xcmappingmodel'
                end
                dir_build_file.should.be.not.nil

                # An item within the model directory should not be present.
                xml_file = @bundle_target.resources_build_phase.files.find do |bf|
                  bf.file_ref.path =~ %r{Resources/Migration\.xcmappingmodel/.*}i
                end
                xml_file.should.be.nil
              end
            end

            describe 'xcframeworks' do
              it 'raises if a vendored xcframework has slices of mixed linkage' do
                @pod_target.stubs(:xcframeworks).returns('Debug' => [Pod::Xcode::XCFramework.new(fixture('CoconutLib.xcframework'))])
                Pod::Xcode::LinkageAnalyzer.stubs(:dynamic_binary?).returns(true, false, true, false, true, false, true)
                e = ->() { @installer.install! }.should.raise Informative
                e.message.should.include? 'Unable to install vendored xcframework `CoconutLib` for Pod `BananaLib`, because it contains both static and dynamic frameworks.'
              end

              it 'raises if a vendored xcframework is empty' do
                xcframework = Pod::Xcode::XCFramework.new(fixture('CoconutLib.xcframework'))
                xcframework.stubs(:slices).returns([])
                @pod_target.stubs(:xcframeworks).returns('Debug' => [xcframework])
                e = ->() { @installer.install! }.should.raise Informative
                e.message.should.include? 'Unable to install vendored xcframework `CoconutLib` for Pod `BananaLib` because it does not contain any binaries.'
              end

              it 'raises if a vendored xcframework with static libraries has mutliple library names' do
                slices = [
                  stub('sliceA', :binary_path => Pathname.new('/tmp/path/to/libSliceA.a'), :build_type => BuildType.static_library),
                  stub('sliceB', :binary_path => Pathname.new('/tmp/path/to/libSliceB.a'), :build_type => BuildType.static_library),
                ]
                xcframework = stub('xcframework', :name => 'CoconutLib', :build_type => BuildType.static_library, :slices => slices)
                @pod_target.stubs(:xcframeworks).returns('Debug' => [xcframework])
                e = ->() { @installer.install! }.should.raise Informative
                e.message.should.include? <<-MSG.strip_heredoc
                Unable to install vendored xcframework `CoconutLib` for Pod `BananaLib` because it contains static libraries
                with differing binary names: libSliceA and libSliceB.
                MSG
              end

              it 'raises if a vendored xcframework uses dynamic libraries' do
                xcframework = stub('xcframework', :name => 'CoconutLib', :build_type => BuildType.dynamic_library, :slices => [stub('Slice')])
                @pod_target.stubs(:xcframeworks).returns('Debug' => [xcframework])
                e = ->() { @installer.install! }.should.raise Informative
                e.message.should.include? <<-MSG.strip_heredoc
                Unable to install vendored xcframework `CoconutLib` for Pod `BananaLib` because it contains dynamic libraries which are not supported.
                Use dynamic frameworks for dynamic linking instead.
                MSG
              end

              it 'creates the copy xcframeworks script phase if needed' do
                @pod_target.stubs(:xcframeworks).returns('Debug' => [Pod::Xcode::XCFramework.new(fixture('CoconutLib.xcframework'))])
                @installer.expects(:create_copy_xcframeworks_script).once
                @installer.install!
              end
            end
          end
        end
      end
    end
  end
end
