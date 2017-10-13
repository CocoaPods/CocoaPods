module Pod
  module Generator
    # Stores the common logic for creating app targets within projects including
    # generating standard import and main files for app hosts.
    #
    module AppTargetHelper
      # Adds a single app target to the given project with the provided name.
      #
      # @param  [Project] project
      #         the Xcodeproj to generate the target into.
      #
      # @param  [Symbol] platform
      #         the platform of the target. Can be `:ios` or `:osx`, etc.
      #
      # @param  [String] deployment_target
      #         the deployment target for the platform.
      #
      # @param  [String] name
      #         The name to use for the target, defaults to 'App'.
      #
      # @return [PBXNativeTarget] the new target that was created.
      #
      def self.add_app_target(project, platform, deployment_target, name = 'App')
        project.new_target(:application, name, platform, deployment_target)
      end

      # Creates and links an import file for the given pod target and into the given native target.
      #
      # @param  [Project] project
      #         the Xcodeproj to generate the target into.
      #
      # @param  [PBXNativeTarget] target
      #         the native target to link the generated import file into.
      #
      # @param  [PodTarget] pod_target
      #         the pod target to use for when generating the contents of the import file.
      #
      # @param  [Symbol] platform
      #         the platform of the target. Can be `:ios` or `:osx`, etc.
      #
      # @param  [Boolean] use_frameworks
      #         whether to use frameworks or not when generating the contents of the import file.
      #
      # @param  [String] name
      #         The name to use for the target, defaults to 'App'.
      #
      # @return [Array<PBXBuildFile>] the created build file references.
      #
      def self.add_app_project_import(project, target, pod_target, platform, use_frameworks, name = 'App')
        source_file = AppTargetHelper.create_app_import_source_file(project, pod_target, platform, use_frameworks, name)
        source_file_ref = project.new_group(name, name).new_file(source_file)
        target.add_file_references([source_file_ref])
      end

      # Creates and links a default app host 'main.m' file.
      #
      # @param  [Project] project
      #         the Xcodeproj to generate the target into.
      #
      # @param  [PBXNativeTarget] target
      #         the native target to link the generated main file into.
      #
      # @param  [Symbol] platform
      #         the platform of the target. Can be `:ios` or `:osx`, etc.
      #
      # @param  [String] name
      #         The name to use for the target, defaults to 'App'.
      #
      # @return [Array<PBXBuildFile>] the created build file references.
      #
      def self.add_app_host_main_file(project, target, platform, name = 'App')
        source_file = AppTargetHelper.create_app_host_main_file(project, platform, name)
        source_file_ref = project.new_group(name, name).new_file(source_file)
        target.add_file_references([source_file_ref])
      end

      # Adds the xctest framework search paths into the given target.
      #
      # @param  [PBXNativeTarget] target
      #         the native target to add XCTest into.
      #
      # @return [void]
      #
      def self.add_xctest_search_paths(target)
        target.build_configurations.each do |configuration|
          search_paths = configuration.build_settings['FRAMEWORK_SEARCH_PATHS'] ||= '$(inherited)'
          search_paths << ' "$(PLATFORM_DIR)/Developer/Library/Frameworks"'
        end
      end

      # Adds the provided swift version into the given target.
      #
      # @param  [PBXNativeTarget] target
      #         the native target to add the swift version into.
      #
      # @param  [String] swift_version
      #         the swift version to set to.
      #
      # @return [void]
      #
      def self.add_swift_version(target, swift_version)
        raise 'Cannot set empty Swift version to target.' if swift_version.blank?
        target.build_configurations.each do |configuration|
          configuration.build_settings['SWIFT_VERSION'] = swift_version
        end
      end

      # Creates a default import file for the given pod target.
      #
      # @param  [Project] project
      #         the Xcodeproj to generate the target into.
      #
      # @param  [PodTarget] pod_target
      #         the pod target to use for when generating the contents of the import file.
      #
      # @param  [Symbol] platform
      #         the platform of the target. Can be `:ios` or `:osx`, etc.
      #
      # @param  [Boolean] use_frameworks
      #         whether to use frameworks or not when generating the contents of the import file.
      #
      # @param  [String] name
      #         The name of the folder to use and save the generated main file.
      #
      # @return [Pathname] the new source file that was generated.
      #
      def self.create_app_import_source_file(project, pod_target, platform, use_frameworks, name = 'App')
        language = pod_target.uses_swift? ? :swift : :objc

        if language == :swift
          source_file = project.path.dirname.+("#{name}/main.swift")
          source_file.parent.mkpath
          import_statement = use_frameworks && pod_target.should_build? ? "import #{pod_target.product_module_name}\n" : ''
          source_file.open('w') { |f| f << import_statement }
        else
          source_file = project.path.dirname.+("#{name}/main.m")
          source_file.parent.mkpath
          import_statement = if use_frameworks && pod_target.should_build?
                               "@import #{pod_target.product_module_name};\n"
                             else
                               header_name = "#{pod_target.product_module_name}/#{pod_target.product_module_name}.h"
                               if pod_target.sandbox.public_headers.root.+(header_name).file?
                                 "#import <#{header_name}>\n"
                               else
                                 ''
                               end
                             end
          source_file.open('w') do |f|
            f << "@import Foundation;\n"
            f << "@import UIKit;\n" if platform == :ios || platform == :tvos
            f << "@import Cocoa;\n" if platform == :osx
            f << "#{import_statement}int main() {}\n"
          end
        end
        source_file
      end

      # Creates a default app host 'main.m' file.
      #
      # @param  [Project] project
      #         the Xcodeproj to generate the target into.
      #
      # @param  [Symbol] platform
      #         the platform of the target. Can be `:ios` or `:osx`.
      #
      # @param  [String] name
      #         The name of the folder to use and save the generated main file.
      #
      # @return [Pathname] the new source file that was generated.
      #
      def self.create_app_host_main_file(project, platform, name = 'App')
        source_file = project.path.dirname.+("#{name}/main.m")
        source_file.parent.mkpath
        source_file.open('w') do |f|
          case platform
          when :ios, :tvos
            f << IOS_APP_HOST_MAIN_CONTENTS
          when :osx
            f << MACOS_APP_APP_HOST_MAIN_CONTENTS
          end
        end
        source_file
      end

      IOS_APP_HOST_MAIN_CONTENTS = <<EOS.freeze
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface CPTestAppHostAppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic, strong) UIWindow *window;

@end

@implementation CPTestAppHostAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [UIViewController new];

    [self.window makeKeyAndVisible];

    return YES;
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool
    {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([CPTestAppHostAppDelegate class]));
    }
}
EOS

      MACOS_APP_APP_HOST_MAIN_CONTENTS = <<EOS.freeze
#import <Cocoa/Cocoa.h>

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}
EOS
    end
  end
end
