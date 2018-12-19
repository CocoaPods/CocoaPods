module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        # Installs an app host target to a given project.
        #
        class AppHostInstaller
          include TargetInstallerHelper

          # @return [Sandbox]
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

          # @return [String] the name to use for this app host target.
          #
          attr_reader :name

          # @return [String] the name of the pod the app host installer will be installing within.
          #
          attr_reader :pod_name

          # Initialize a new instance
          #
          # @param [Sandbox] sandbox @see #sandbox
          # @param [Pod::Project] project @see #project
          # @param [Platform] platform @see #platform
          # @param [String] name @see #name
          # @param [String] pod_name @see #pod_name
          #
          def initialize(sandbox, project, platform, name, pod_name)
            @sandbox = sandbox
            @project = project
            @platform = platform
            @name = name
            @pod_name = pod_name
            target_group = project.pod_group(pod_name)
            @group = target_group[name] || target_group.new_group(name)
          end

          # @return [PBXNativeTarget] the app host native target that was installed.
          #
          def install!
            platform_name = platform.name
            app_host_target = Pod::Generator::AppTargetHelper.add_app_target(project, platform_name, deployment_target,
                                                                             name)
            app_host_target.build_configurations.each do |configuration|
              configuration.build_settings['PRODUCT_NAME'] = name
              configuration.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'org.cocoapods.${PRODUCT_NAME:rfc1034identifier}'
              configuration.build_settings['CODE_SIGN_IDENTITY'] = '' if platform == :osx
              configuration.build_settings['CURRENT_PROJECT_VERSION'] = '1'
            end

            Pod::Generator::AppTargetHelper.add_app_host_main_file(project, app_host_target, platform_name, @group, name)
            Pod::Generator::AppTargetHelper.add_launchscreen_storyboard(project, app_host_target, @group, deployment_target, name) if platform == :ios
            additional_entries = platform == :ios ? ADDITIONAL_IOS_INFO_PLIST_ENTRIES : {}
            create_info_plist_file_with_sandbox(sandbox, app_host_info_plist_path, app_host_target, '1.0.0', platform,
                                                :appl, additional_entries)
            @group.new_file(app_host_info_plist_path)
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
            project.path.dirname.+(name).+("#{name}-Info.plist")
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
