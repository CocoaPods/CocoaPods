require File.expand_path('../../../../../spec_helper', __FILE__)
require 'fileutils'
require 'cocoapods/installer/xcode/pods_project_generator/project_generator'

module Pod
  class Installer
    class Xcode
      describe ProjectGenerator do
        before do
          @ios_platform = Platform.new(:ios, '6.0')
          @osx_platform = Platform.new(:osx, '10.8')

          @ios_target_definition = fixture_target_definition('SampleApp-iOS', @ios_platform)
          @osx_target_definition = fixture_target_definition('SampleApp-macOS', @osx_platform)

          user_build_configurations = { 'Debug' => :debug, 'Release' => :release, 'App Store' => :release, 'Test' => :debug }

          @monkey_spec = fixture_spec('monkey/monkey.podspec')
          @monkey_ios_pod_target = fixture_pod_target(@monkey_spec, BuildType.static_library,
                                                      user_build_configurations, [], @ios_platform,
                                                      [@ios_target_definition], 'iOS')
          @monkey_osx_pod_target = fixture_pod_target(@monkey_spec, BuildType.static_library,
                                                      user_build_configurations, [], @osx_platform,
                                                      [@osx_target_definition], 'macOS')

          @banana_spec = fixture_spec('banana-lib/BananaLib.podspec')
          @banana_ios_pod_target = fixture_pod_target(@banana_spec, BuildType.static_library,
                                                      user_build_configurations, [], @ios_platform,
                                                      [@ios_target_definition], 'iOS')
          @banana_osx_pod_target = fixture_pod_target(@banana_spec, BuildType.static_library,
                                                      user_build_configurations, [], @osx_platform,
                                                      [@osx_target_definition], 'macOS')

          @orangeframework_spec = fixture_spec('orange-framework/OrangeFramework.podspec')
          @orangeframework_pod_target = fixture_pod_target_with_specs([@orangeframework_spec],
                                                                      BuildType.static_library,
                                                                      user_build_configurations, [], @ios_platform,
                                                                      [@ios_target_definition])

          @coconut_spec = fixture_spec('coconut-lib/CoconutLib.podspec')
          @coconut_test_spec = @coconut_spec.test_specs.first
          @coconut_ios_pod_target = fixture_pod_target_with_specs([@coconut_spec, @coconut_test_spec],
                                                                  BuildType.static_library,
                                                                  user_build_configurations, [], @ios_platform,
                                                                  [@ios_target_definition],
                                                                  'iOS')
          @coconut_ios_pod_target.dependent_targets = [@orangeframework_pod_target]
          @coconut_osx_pod_target = fixture_pod_target_with_specs([@coconut_spec, @coconut_test_spec],
                                                                  BuildType.static_library,
                                                                  user_build_configurations, [], @osx_platform,
                                                                  [@osx_target_definition],
                                                                  'macOS')

          @watermelon_spec = fixture_spec('watermelon-lib/WatermelonLib.podspec')
          @watermelon_ios_pod_target = fixture_pod_target_with_specs([@watermelon_spec,
                                                                      *@watermelon_spec.recursive_subspecs],
                                                                     BuildType.static_library,
                                                                     user_build_configurations, [],
                                                                     Platform.new(:ios, '9.0'),
                                                                     [@ios_target_definition], 'iOS')
          @watermelon_osx_pod_target = fixture_pod_target_with_specs([@watermelon_spec,
                                                                      *@watermelon_spec.recursive_subspecs],
                                                                     BuildType.static_library,
                                                                     user_build_configurations, [], @osx_platform,
                                                                     [@osx_target_definition], 'macOS')

          @grapefruits_spec = fixture_spec('grapefruits-lib/GrapefruitsLib.podspec')
          @grapefruits_app_spec = @grapefruits_spec.app_specs.first
          @grapefruits_ios_pod_target = fixture_pod_target_with_specs([@grapefruits_spec,
                                                                       @grapefruits_app_spec],
                                                                      BuildType.static_library,
                                                                      user_build_configurations, [], @ios_platform,
                                                                      [@ios_target_definition], 'iOS')
          @grapefruits_ios_pod_target.app_dependent_targets_by_spec_name = { @grapefruits_app_spec.name => [@banana_ios_pod_target] }

          @pineapple_spec = fixture_spec('pineapple-lib/PineappleLib.podspec')
          @pineapple_app_spec = @pineapple_spec.app_specs.first
          @pineapple_test_spec = @pineapple_spec.test_specs.first
          @pineapple_ios_pod_target = fixture_pod_target_with_specs([@pineapple_spec, *@pineapple_spec.recursive_subspecs],
                                                                    BuildType.dynamic_framework,
                                                                    user_build_configurations, [], Platform.new(:ios, '13.0'),
                                                                    [@ios_target_definition], 'iOS')
          @pineapple_ios_pod_target.app_dependent_targets_by_spec_name = { @pineapple_app_spec.name => [@pineapple_ios_pod_target] }
          @pineapple_ios_pod_target.test_app_hosts_by_spec = @pineapple_spec.test_specs.each_with_object({}) do |test_spec, hash|
            hash[test_spec] = [@pineapple_app_spec, @pineapple_ios_pod_target]
          end

          ios_pod_targets = [@banana_ios_pod_target, @monkey_ios_pod_target, @coconut_ios_pod_target,
                             @orangeframework_pod_target, @watermelon_ios_pod_target, @grapefruits_ios_pod_target, @pineapple_ios_pod_target]
          osx_pod_targets = [@banana_osx_pod_target, @monkey_osx_pod_target, @coconut_osx_pod_target, @watermelon_osx_pod_target]
          pod_targets = ios_pod_targets + osx_pod_targets

          @ios_target = fixture_aggregate_target(ios_pod_targets, BuildType.static_library, user_build_configurations,
                                                 [], @ios_platform, @ios_target_definition)
          @osx_target = fixture_aggregate_target(osx_pod_targets, BuildType.static_library, user_build_configurations,
                                                 [], @osx_platform, @osx_target_definition)

          aggregate_targets = [@ios_target, @osx_target]

          @analysis_result = Pod::Installer::Analyzer::AnalysisResult.new(Pod::Installer::Analyzer::SpecsState.new,
                                                                          {}, {}, [],
                                                                          Pod::Installer::Analyzer::SpecsState.new,
                                                                          aggregate_targets, pod_targets, nil)

          @installation_options = Pod::Installer::InstallationOptions.new

          @platforms = aggregate_targets.map(&:platform)
          @generator = ProjectGenerator.new(config.sandbox, config.sandbox.project_path, pod_targets, @analysis_result.all_user_build_configurations, @platforms, nil)
        end

        it 'includes all build configurations' do
          project = @generator.generate!
          project.build_configurations.map(&:name).sort.should == [
            'App Store',
            'Debug',
            'Release',
            'Test',
          ]
        end

        it 'adds a reference to the Podfile' do
          podfile_path = SpecHelper.temporary_directory + 'Podfile'
          puts podfile_path
          File.open(podfile_path, 'w') { |f| f.write "\n" }
          generator = ProjectGenerator.new(@generator.sandbox, @generator.path, @generator.pod_targets, @generator.build_configurations,
                                           @generator.platforms, @generator.object_version, podfile_path)
          project = generator.generate!
          project.main_group.find_subpath('Podfile').should.not.be.nil?
        end

        it 'creates a group for each pod' do
          project = @generator.generate!
          project.main_group['Pods'].groups.map(&:name).sort.should == %w(
            BananaLib
            CoconutLib
            GrapefruitsLib
            OrangeFramework
            PineappleLib
            WatermelonLib
            monkey
          )
        end

        describe 'project object version' do
          it 'uses a default when nil' do
            project = @generator.generate!
            project.object_version.should == Xcodeproj::Constants::DEFAULT_OBJECT_VERSION.to_s
          end

          it 'respects object_version when provided' do
            generator = ProjectGenerator.new(@generator.sandbox, @generator.path, @generator.pod_targets, @generator.build_configurations,
                                             @generator.platforms, 50)
            project = generator.generate!
            project.object_version.should == '50'
          end
        end

        describe 'default build settings' do
          before do
            @project = @generator.generate!
          end

          it 'contains build configurations' do
            @project.build_configurations.should.not.be.empty?
          end

          it 'sets `SYMROOT`' do
            @project.build_configurations.map { |bc| bc.build_settings['SYMROOT'] }.uniq.should == ['${SRCROOT}/../build']
          end

          it 'sets iOS deployment target to the minimum of all targets' do
            @project.build_configurations.map { |bc| bc.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] }.uniq.should == ['6.0']
          end

          it 'sets macOS deployment target to the minimum of all targets' do
            @project.build_configurations.map { |bc| bc.build_settings['MACOSX_DEPLOYMENT_TARGET'] }.uniq.should == ['10.8']
          end

          it 'sets `STRIP_INSTALLED_PRODUCT`' do
            @project.build_configurations.map { |bc| bc.build_settings['STRIP_INSTALLED_PRODUCT'] }.uniq.should == ['NO']
          end

          it 'enables ARC' do
            @project.build_configurations.map { |bc| bc.build_settings['CLANG_ENABLE_OBJC_ARC'] }.uniq.should == ['YES']
          end

          it 'enables missing localization warning' do
            @project.build_configurations.map { |bc| bc.build_settings['CLANG_ANALYZER_LOCALIZABILITY_NONLOCALIZED'] }.uniq.should == ['YES']
          end
        end
      end
    end
  end
end
