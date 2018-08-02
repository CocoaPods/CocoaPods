module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        # Installs an app host target to a given project.
        #
        class AppHostInstaller
          include TargetInstallerHelper

          # @return [Sandbox] sandbox
          #         The sandbox used for this installation.
          #
          attr_reader :sandbox

          # @return [Pod::Project]
          #         The `Pods/Pods.xcodeproj` to install the app host into.
          #
          attr_reader :project

          # @return [Platform] the platform to use for this app host.
          #
          attr_reader :platform

          # @return [Symbol] the test type this app host is going to be used for.
          #
          attr_reader :test_type

          # Initialize a new instance
          #
          # @param [Sandbox] sandbox @see #sandbox
          # @param [Pod::Project] project @see #project
          # @param [Platform] platform @see #platform
          # @param [Symbol] test_type @see #test_type
          #
          def initialize(sandbox, project, platform, test_type)
            @sandbox = sandbox
            @project = project
            @platform = platform
            @test_type = test_type
          end

          # @return [PBXNativeTarget] the app host native target that was installed.
          #
          def install!
            name = app_host_label
            platform_name = platform.name
            app_host_target = Pod::Generator::AppTargetHelper.add_app_target(project, platform_name, deployment_target,
                                                                             name)
            app_host_target.build_configurations.each do |configuration|
              configuration.build_settings['PRODUCT_NAME'] = name
              configuration.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'org.cocoapods.${PRODUCT_NAME:rfc1034identifier}'
              configuration.build_settings['CODE_SIGN_IDENTITY'] = '' if platform == :osx
              configuration.build_settings['CURRENT_PROJECT_VERSION'] = '1'
            end
            Pod::Generator::AppTargetHelper.add_app_host_main_file(project, app_host_target, platform_name, name)
            Pod::Generator::AppTargetHelper.add_launchscreen_storyboard(project, app_host_target, name) if platform == :ios
            additional_entries = platform == :ios ? ADDITIONAL_IOS_INFO_PLIST_ENTRIES : {}
            create_info_plist_file_with_sandbox(sandbox, app_host_info_plist_path, app_host_target, '1.0.0', platform,
                                                :appl, additional_entries)
            project[name].new_file(app_host_info_plist_path)
            app_host_target
          end

          private

          ADDITIONAL_IOS_INFO_PLIST_ENTRIES = {
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
          }.freeze

          # @return [Pathname] The absolute path of the Info.plist to use for an app host.
          #
          def app_host_info_plist_path
            project.path.dirname.+("#{app_host_label}/#{app_host_label}-Info.plist")
          end

          # @return [String] The label of the app host label to use given the platform and test type.
          #
          def app_host_label
            "AppHost-#{Platform.string_name(platform.symbolic_name)}-#{test_type.capitalize}-Tests"
          end

          # @return [String] The deployment target.
          #
          def deployment_target
            platform.deployment_target.to_s
          end
        end
      end
    end
  end
end
