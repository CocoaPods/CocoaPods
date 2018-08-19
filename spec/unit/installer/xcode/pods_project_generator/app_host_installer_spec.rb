require File.expand_path('../../../../../spec_helper', __FILE__)

module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        describe AppHostInstaller do
          before do
            @project = Project.new(config.sandbox.project_path)
            config.sandbox.project = @project
          end

          it 'correctly installs an iOS app host target to the project' do
            installer = AppHostInstaller.new(config.sandbox, @project, Platform.ios, 'AppHost-PodName-iOS-Unit-Tests')
            installer.install!
            @project.targets.map(&:name).sort.should == ['AppHost-PodName-iOS-Unit-Tests']
          end

          it 'correctly installs an OSX app host target to the project' do
            installer = AppHostInstaller.new(config.sandbox, @project, Platform.osx, 'AppHost-PodName-macOS-Unit-Tests')
            installer.install!
            @project.targets.map(&:name).sort.should == ['AppHost-PodName-macOS-Unit-Tests']
          end

          it 'sets the correct build settings for an iOS app host target' do
            installer = AppHostInstaller.new(config.sandbox, @project, Platform.ios, 'AppHost-PodName-iOS-Unit-Tests')
            app_host_target = installer.install!
            build_settings = app_host_target.build_configurations.map(&:build_settings)
            build_settings.each do |build_setting|
              build_setting['PRODUCT_NAME'].should == 'AppHost-PodName-iOS-Unit-Tests'
              build_setting['PRODUCT_BUNDLE_IDENTIFIER'].should == 'org.cocoapods.${PRODUCT_NAME:rfc1034identifier}'
              build_setting['CODE_SIGN_IDENTITY'].should == 'iPhone Developer'
              build_setting['CURRENT_PROJECT_VERSION'].should == '1'
            end
          end

          it 'sets the correct build settings for an OSX app host target' do
            installer = AppHostInstaller.new(config.sandbox, @project, Platform.osx, 'AppHost-PodName-macOS-Unit-Tests')
            app_host_target = installer.install!
            build_settings = app_host_target.build_configurations.map(&:build_settings)
            build_settings.each do |build_setting|
              build_setting['PRODUCT_NAME'].should == 'AppHost-PodName-macOS-Unit-Tests'
              build_setting['PRODUCT_BUNDLE_IDENTIFIER'].should == 'org.cocoapods.${PRODUCT_NAME:rfc1034identifier}'
              build_setting['CODE_SIGN_IDENTITY'].should.be.empty
              build_setting['CURRENT_PROJECT_VERSION'].should == '1'
            end
          end
        end
      end
    end
  end
end
