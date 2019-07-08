require File.expand_path('../../../../../spec_helper', __FILE__)

module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        describe AppHostInstaller do
          before do
            @project = Project.new(config.sandbox.project_path)
            @project.add_pod_group('Subgroup', '')
          end

          it 'correctly installs an iOS app host target to the project' do
            installer = AppHostInstaller.new(config.sandbox, @project, Platform.ios,
                                             'AppHost-PodName-iOS-Unit-Tests',
                                             'Subgroup',
                                             'AppHost-PodName-iOS-Unit-Tests')
            installer.install!
            @project.targets.map(&:name).sort.should == ['AppHost-PodName-iOS-Unit-Tests']
          end

          it 'correctly installs an OSX app host target to the project' do
            installer = AppHostInstaller.new(config.sandbox, @project, Platform.osx,
                                             'AppHost-PodName-macOS-Unit-Tests',
                                             'Subgroup',
                                             'AppHost-PodName-macOS-Unit-Tests')
            installer.install!
            @project.targets.map(&:name).sort.should == ['AppHost-PodName-macOS-Unit-Tests']
          end

          it 'correctly adds app files under specified group' do
            name = 'AppHost-PodName-iOS-Unit-Tests'
            installer = AppHostInstaller.new(config.sandbox, @project, Platform.ios,
                                             name,
                                             'Subgroup',
                                             name)
            installer.install!
            @project.pod_group('Subgroup')[name].files.map(&:name).sort.should == [
              'AppHost-PodName-iOS-Unit-Tests-Info.plist',
              'LaunchScreen.storyboard',
              'main.m',
            ]
          end

          it 'does not add main to the group' do
            name = 'AppHost-PodName-iOS-Unit-Tests'
            installer = AppHostInstaller.new(config.sandbox, @project, Platform.ios,
                                             name,
                                             'Subgroup',
                                             name,
                                             :add_main => false)
            installer.install!
            @project.pod_group('Subgroup')[name].files.map(&:name).sort.should == [
              'AppHost-PodName-iOS-Unit-Tests-Info.plist',
              'LaunchScreen.storyboard',
            ]
          end

          it 'sets the correct build settings for an iOS app host target' do
            installer = AppHostInstaller.new(config.sandbox, @project, Platform.ios,
                                             'AppHost-PodName-iOS-Unit-Tests',
                                             'Subgroup',
                                             'AppHost-PodName-iOS-Unit-Tests')
            app_host_target = installer.install!
            build_settings = app_host_target.build_configurations.map(&:build_settings)
            build_settings.each do |build_setting|
              build_setting['PRODUCT_NAME'].should == 'AppHost-PodName-iOS-Unit-Tests'
              build_setting['PRODUCT_BUNDLE_IDENTIFIER'].should == 'org.cocoapods.${PRODUCT_NAME:rfc1034identifier}'
              build_setting['CODE_SIGN_IDENTITY'].should == 'iPhone Developer'
              build_setting['CURRENT_PROJECT_VERSION'].should == '1'
            end
          end

          it 'sets the correct build settings for an iOS app host target with separate target label' do
            installer = AppHostInstaller.new(config.sandbox, @project, Platform.ios,
                                             'AppHost-PodName-iOS-Unit-Tests',
                                             'Subgroup',
                                             'AppName')
            app_host_target = installer.install!
            build_settings = app_host_target.build_configurations.map(&:build_settings)
            build_settings.each do |build_setting|
              build_setting['PRODUCT_NAME'].should == 'AppName'
              build_setting['PRODUCT_BUNDLE_IDENTIFIER'].should == 'org.cocoapods.${PRODUCT_NAME:rfc1034identifier}'
              build_setting['CODE_SIGN_IDENTITY'].should == 'iPhone Developer'
              build_setting['CURRENT_PROJECT_VERSION'].should == '1'
            end
          end

          it 'sets the correct build settings for an OSX app host target' do
            installer = AppHostInstaller.new(config.sandbox, @project, Platform.osx,
                                             'AppHost-PodName-macOS-Unit-Tests',
                                             'Subgroup',
                                             'AppHost-PodName-macOS-Unit-Tests')
            app_host_target = installer.install!
            build_settings = app_host_target.build_configurations.map(&:build_settings)
            build_settings.each do |build_setting|
              build_setting['PRODUCT_NAME'].should == 'AppHost-PodName-macOS-Unit-Tests'
              build_setting['PRODUCT_BUNDLE_IDENTIFIER'].should == 'org.cocoapods.${PRODUCT_NAME:rfc1034identifier}'
              build_setting['CODE_SIGN_IDENTITY'].should.be.empty
              build_setting['CURRENT_PROJECT_VERSION'].should == '1'
            end
          end

          it 'creates an Info.plist for the app host target' do
            info_plist_entries = { 'CFBundleIdentifier' => 'org.cocoapods.MyApp' }
            installer = AppHostInstaller.new(config.sandbox, @project, Platform.ios,
                                             'AppHost-PodName-iOS-Unit-Tests',
                                             'Subgroup',
                                             'AppName',
                                             :info_plist_entries => info_plist_entries)
            expected_entries = {
              'NSAppTransportSecurity' => {
                'NSAllowsArbitraryLoads' => true,
              },
              'UILaunchStoryboardName' => 'LaunchScreen',
              'UISupportedInterfaceOrientations' => %w(
                UIInterfaceOrientationPortrait
                UIInterfaceOrientationLandscapeLeft
                UIInterfaceOrientationLandscapeRight
              ),
              'UISupportedInterfaceOrientations~ipad' => %w(
                UIInterfaceOrientationPortrait
                UIInterfaceOrientationPortraitUpsideDown
                UIInterfaceOrientationLandscapeLeft
                UIInterfaceOrientationLandscapeRight
              ),
            }.merge(info_plist_entries)
            installer.expects(:create_info_plist_file_with_sandbox).
              with do |sandbox, _, _, version, platform, bundle_type, other_args|
              sandbox.should == config.sandbox
              version.should == '1.0.0'
              platform.should == :ios
              bundle_type.should == :appl
              other_args[:additional_entries].should == expected_entries
            end
            installer.install!
          end

          describe '#additional_info_plist_entries' do
            before do
              @installer = AppHostInstaller.new(config.sandbox, @project, Platform.ios,
                                                'AppHost-PodName-iOS-Unit-Tests',
                                                'Subgroup',
                                                'AppName')
            end

            it 'includes iOS specific entries' do
              @installer.stubs(:platform).returns(Platform.ios)
              expected = {
                'NSAppTransportSecurity' => {
                  'NSAllowsArbitraryLoads' => true,
                },
                'UILaunchStoryboardName' => 'LaunchScreen',
                'UISupportedInterfaceOrientations' => %w(
                  UIInterfaceOrientationPortrait
                  UIInterfaceOrientationLandscapeLeft
                  UIInterfaceOrientationLandscapeRight
                ),
                'UISupportedInterfaceOrientations~ipad' => %w(
                  UIInterfaceOrientationPortrait
                  UIInterfaceOrientationPortraitUpsideDown
                  UIInterfaceOrientationLandscapeLeft
                  UIInterfaceOrientationLandscapeRight
                ),
              }
              result = @installer.send(:additional_info_plist_entries)
              result.should == expected
            end

            it 'includes macOS specific entries' do
              @installer.stubs(:platform).returns(Platform.osx)
              expected = {
                'NSAppTransportSecurity' => {
                  'NSAllowsArbitraryLoads' => true,
                },
              }
              result = @installer.send(:additional_info_plist_entries)
              result.should == expected
            end

            it 'includes tvOS specific entries' do
              @installer.stubs(:platform).returns(Platform.tvos)
              expected = {
                'NSAppTransportSecurity' => {
                  'NSAllowsArbitraryLoads' => true,
                },
              }
              result = @installer.send(:additional_info_plist_entries)
              result.should == expected
            end

            it 'includes info_plist_entries when provided' do
              installer = AppHostInstaller.new(config.sandbox, @project, Platform.tvos,
                                               'AppHost-PodName-iOS-Unit-Tests',
                                               'Subgroup',
                                               'AppName',
                                               :info_plist_entries => { 'SOME_VAR' => 'SOME_VALUE' })
              expected = {
                'NSAppTransportSecurity' => {
                  'NSAllowsArbitraryLoads' => true,
                },
                'SOME_VAR' => 'SOME_VALUE',
              }
              result = installer.send(:additional_info_plist_entries)
              result.should == expected
            end
          end
        end
      end
    end
  end
end
