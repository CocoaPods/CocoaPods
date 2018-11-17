require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  module Generator
    module AppTargetHelper
      describe 'creating the import file' do
        describe 'when linting as a framework' do
          it 'creates a swift import' do
            pod_target = stub('PodTarget', :uses_swift? => true, :should_build? => true,
                                           :product_module_name => 'ModuleName', :name => 'ModuleName',
                                           :defines_module? => true, :recursive_dependent_targets => [])
            project = stub('Project', :path => Pathname(Dir.mktmpdir(['CocoaPods-Lint-', "-#{pod_target.name}"])) + 'App.xcodeproj')

            file = AppTargetHelper.create_app_import_source_file(project, pod_target, :ios)
            file.basename.to_s.should == 'main.swift'
            file.read.should == <<-SWIFT.strip_heredoc
                import ModuleName
            SWIFT
          end

          it 'creates an objective-c import' do
            pod_target = stub('PodTarget', :uses_swift? => false, :should_build? => true,
                                           :product_module_name => 'ModuleName', :name => 'ModuleName',
                                           :defines_module? => true, :recursive_dependent_targets => [])
            project = stub('Project', :path => Pathname(Dir.mktmpdir(['CocoaPods-Lint-', "-#{pod_target.name}"])) + 'App.xcodeproj')

            file = AppTargetHelper.create_app_import_source_file(project, pod_target, :ios)
            file.basename.to_s.should == 'main.m'
            file.read.should == <<-OBJC.strip_heredoc
                @import Foundation;
                @import UIKit;
                @import ModuleName;
                int main() {}
            OBJC
          end

          it 'creates no import when the pod target has no source files' do
            pod_target = stub('PodTarget', :uses_swift? => true, :should_build? => false, :name => 'ModuleName',
                                           :recursive_dependent_targets => [])
            project = stub('Project', :path => Pathname(Dir.mktmpdir(['CocoaPods-Lint-', "-#{pod_target.name}"])) + 'App.xcodeproj')

            file = AppTargetHelper.create_app_import_source_file(project, pod_target, :ios)
            file.basename.to_s.should == 'main.swift'
            file.read.should == ''
          end
        end

        describe 'when linting as a static lib' do
          before do
            @sandbox = config.sandbox
          end

          it 'creates an objective-c import when a plausible umbrella header is found' do
            pod_target = stub('PodTarget', :uses_swift? => false, :should_build? => true,
                                           :product_module_name => 'ModuleName', :name => 'ModuleName',
                                           :sandbox => @sandbox, :defines_module? => false,
                                           :recursive_dependent_targets => [])
            project = stub('Project', :path => Pathname(Dir.mktmpdir(['CocoaPods-Lint-', "-#{pod_target.name}"])) + 'App.xcodeproj')
            header_name = "#{pod_target.product_module_name}/#{pod_target.product_module_name}.h"
            umbrella = pod_target.sandbox.public_headers.root.+(header_name)
            umbrella.dirname.mkpath
            umbrella.open('w') {}

            file = AppTargetHelper.create_app_import_source_file(project, pod_target, :ios)
            file.basename.to_s.should == 'main.m'
            file.read.should == <<-OBJC.strip_heredoc
                @import Foundation;
                @import UIKit;
                #import <ModuleName/ModuleName.h>
                int main() {}
            OBJC
          end

          it 'does not create an objective-c import when no umbrella header is found' do
            pod_target = stub('PodTarget', :uses_swift? => false, :should_build? => true,
                                           :product_module_name => 'ModuleName', :name => 'ModuleName',
                                           :sandbox => @sandbox, :defines_module? => false,
                                           :recursive_dependent_targets => [])
            project = stub('Project', :path => Pathname(Dir.mktmpdir(['CocoaPods-Lint-', "-#{pod_target.name}"])) + 'App.xcodeproj')

            file = AppTargetHelper.create_app_import_source_file(project, pod_target, :ios)
            file.basename.to_s.should == 'main.m'
            file.read.should == <<-OBJC.strip_heredoc
                @import Foundation;
                @import UIKit;
                int main() {}
            OBJC
          end
        end
      end

      describe 'creating an app host main file' do
        it 'creates correct main file for iOS' do
          pod_target = stub('PodTarget', :uses_swift? => false, :should_build? => true,
                                         :product_module_name => 'ModuleName', :name => 'ModuleName',
                                         :sandbox => @sandbox)
          project = stub('Project', :path => Pathname(Dir.mktmpdir(['CocoaPods-Lint-', "-#{pod_target.name}"])) + 'App.xcodeproj')

          file = AppTargetHelper.create_app_host_main_file(project, :ios)
          file.basename.to_s.should == 'main.m'
          file.read.should == AppTargetHelper::IOS_APP_HOST_MAIN_CONTENTS
        end

        it 'creates correct main file for macOS' do
          pod_target = stub('PodTarget', :uses_swift? => false, :should_build? => true,
                                         :product_module_name => 'ModuleName', :name => 'ModuleName',
                                         :sandbox => @sandbox)
          project = stub('Project', :path => Pathname(Dir.mktmpdir(['CocoaPods-Lint-', "-#{pod_target.name}"])) + 'App.xcodeproj')

          file = AppTargetHelper.create_app_host_main_file(project, :osx)
          file.basename.to_s.should == 'main.m'
          file.read.should == AppTargetHelper::MACOS_APP_HOST_MAIN_CONTENTS
        end
      end

      describe 'creating a launchscreen storyboard' do
        describe 'on iOS 9 and above' do
          it 'creates the correct launchscreen storyboard contents' do
            pod_target = stub('PodTarget', :uses_swift? => false, :should_build? => true,
                                           :product_module_name => 'ModuleName', :name => 'ModuleName',
                                           :sandbox => @sandbox)
            project = stub('Project', :path => Pathname(Dir.mktmpdir(['CocoaPods-Lint-', "-#{pod_target.name}"])) + 'App.xcodeproj')

            file = AppTargetHelper.create_launchscreen_storyboard_file(project, '9.0')
            file.basename.to_s.should == 'LaunchScreen.storyboard'
            file.read.should == AppTargetHelper::LAUNCHSCREEN_STORYBOARD_CONTENTS
          end
        end

        describe 'on iOS 8' do
          it 'creates the correct launchscreen storyboard contents' do
            pod_target = stub('PodTarget', :uses_swift? => false, :should_build? => true,
                                           :product_module_name => 'ModuleName', :name => 'ModuleName',
                                           :sandbox => @sandbox)
            project = stub('Project', :path => Pathname(Dir.mktmpdir(['CocoaPods-Lint-', "-#{pod_target.name}"])) + 'App.xcodeproj')

            file = AppTargetHelper.create_launchscreen_storyboard_file(project, '8.0')
            file.basename.to_s.should == 'LaunchScreen.storyboard'
            file.read.should == AppTargetHelper::LAUNCHSCREEN_STORYBOARD_CONTENTS_IOS_8
          end
        end
      end
    end
  end
end
