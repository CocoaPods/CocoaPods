require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  class Installer
    class Xcode
      describe MultiPodsProjectGenerator do
        describe 'Generating Multi Pods Project' do
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
            @orangeframework_pod_target = fixture_pod_target_with_specs([@orangeframework_spec], BuildType.static_library,
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
                                                                       user_build_configurations, [], Platform.new(:ios, '9.0'),
                                                                       [@ios_target_definition], 'iOS')
            @watermelon_osx_pod_target = fixture_pod_target_with_specs([@watermelon_spec,
                                                                        *@watermelon_spec.recursive_subspecs],
                                                                       BuildType.static_library,
                                                                       user_build_configurations, [], @osx_platform,
                                                                       [@osx_target_definition], 'macOS')

            @grapefruits_spec = fixture_spec('grapefruits-lib/GrapefruitsLib.podspec')
            @grapefruits_app_spec = @grapefruits_spec.app_specs.first
            @grapefruits_ios_pod_target = fixture_pod_target_with_specs([@grapefruits_spec,
                                                                         @grapefruits_app_spec], BuildType.static_library,
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

            @generator = MultiPodsProjectGenerator.new(config.sandbox, aggregate_targets, pod_targets, @analysis_result.all_user_build_configurations,
                                                       @installation_options, config, 51)
          end

          it "creates build configurations for all projects of the user's targets" do
            pod_generator_result = @generator.generate!
            pods_project = pod_generator_result.project
            pod_target_projects = pod_generator_result.projects_by_pod_targets.keys
            pods_project.build_configurations.map(&:name).sort.should == ['App Store', 'Debug', 'Release', 'Test']
            pod_target_projects.each do |target_project|
              target_project.build_configurations.map(&:name).sort.should == ['App Store', 'Debug', 'Release', 'Test']
            end
          end

          it 'sets STRIP_INSTALLED_PRODUCT to NO for all configurations for all projects' do
            pod_generator_result = @generator.generate!
            pods_project = pod_generator_result.project
            pod_target_projects = pod_generator_result.projects_by_pod_targets.keys
            pods_project.build_settings('Debug')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
            pods_project.build_settings('Test')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
            pods_project.build_settings('Release')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
            pods_project.build_settings('App Store')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
            pod_target_projects.each do |target_project|
              target_project.build_settings('Debug')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
              target_project.build_settings('Test')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
              target_project.build_settings('Release')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
              target_project.build_settings('App Store')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
            end
          end

          it 'sets the SYMROOT to the default value for all configurations for the whole project' do
            pod_generator_result = @generator.generate!
            pods_project = pod_generator_result.project
            pod_target_projects = pod_generator_result.projects_by_pod_targets.keys
            pods_project.build_settings('Debug')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
            pods_project.build_settings('Test')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
            pods_project.build_settings('Release')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
            pods_project.build_settings('App Store')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
            pod_target_projects.each do |target_project|
              target_project.build_settings('Debug')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
              target_project.build_settings('Test')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
              target_project.build_settings('Release')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
              target_project.build_settings('App Store')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
            end
          end

          it 'creates the correct Pods projects' do
            pod_generator_result = @generator.generate!
            pods_project = pod_generator_result.project
            pod_target_projects = pod_generator_result.projects_by_pod_targets.keys
            pods_project.class.should == Pod::Project
            pod_target_projects.each do |target_project|
              target_project.class.should == Pod::Project
            end
          end

          it 'adds the Podfile to the Pods project and not pod target subprojects' do
            config.stubs(:podfile_path).returns(Pathname.new('/Podfile'))
            pod_generator_result = @generator.generate!
            pods_project = pod_generator_result.project
            pod_target_projects = pod_generator_result.projects_by_pod_targets.keys
            pods_project['Podfile'].should.be.not.nil
            pod_target_projects.each do |target_project|
              target_project['Podfile'].should.be.nil
            end
          end

          it 'sets the correct deployment targets for each project' do
            pod_generator_result = @generator.generate!
            pods_project = pod_generator_result.project
            pod_target_projects = pod_generator_result.projects_by_pod_targets.keys
            build_settings = pods_project.build_configurations.map(&:build_settings)
            build_settings.each do |build_setting|
              build_setting['MACOSX_DEPLOYMENT_TARGET'].should == '10.8'
              build_setting['IPHONEOS_DEPLOYMENT_TARGET'].should == '6.0'
            end

            banana_project = pod_target_projects.find { |p| p.path.basename.to_s == 'BananaLib.xcodeproj' }
            monkey_project = pod_target_projects.find { |p| p.path.basename.to_s == 'monkey.xcodeproj' }
            coconut_project = pod_target_projects.find { |p| p.path.basename.to_s == 'CoconutLib.xcodeproj' }
            orange_project = pod_target_projects.find { |p| p.path.basename.to_s == 'OrangeFramework.xcodeproj' }
            watermelon_project = pod_target_projects.find { |p| p.path.basename.to_s == 'WatermelonLib.xcodeproj' }

            banana_project.build_configurations.map(&:build_settings).each do |project_build_settings|
              project_build_settings['MACOSX_DEPLOYMENT_TARGET'].should == '10.8'
              project_build_settings['IPHONEOS_DEPLOYMENT_TARGET'].should == '6.0'
            end

            monkey_project.build_configurations.map(&:build_settings).each do |project_build_settings|
              project_build_settings['MACOSX_DEPLOYMENT_TARGET'].should == '10.8'
              project_build_settings['IPHONEOS_DEPLOYMENT_TARGET'].should == '6.0'
            end

            coconut_project.build_configurations.map(&:build_settings).each do |project_build_settings|
              project_build_settings['MACOSX_DEPLOYMENT_TARGET'].should == '10.8'
              project_build_settings['IPHONEOS_DEPLOYMENT_TARGET'].should == '6.0'
            end

            orange_project.build_configurations.map(&:build_settings).each do |project_build_settings|
              project_build_settings['IPHONEOS_DEPLOYMENT_TARGET'].should == '6.0'
            end

            watermelon_project.build_configurations.map(&:build_settings).each do |project_build_settings|
              project_build_settings['MACOSX_DEPLOYMENT_TARGET'].should == '10.8'
              project_build_settings['IPHONEOS_DEPLOYMENT_TARGET'].should == '9.0'
            end
          end

          it 'adds subproject pods into main group' do
            pod_generator_result = @generator.generate!
            banana_project = pod_generator_result.projects_by_pod_targets.keys.find { |p| p.path.basename.to_s == 'BananaLib.xcodeproj' }
            banana_project.main_group['BananaLib'].should.not.be.nil
          end

          it 'installs file references' do
            pod_generator_result = @generator.generate!
            projects_by_pod_targets = pod_generator_result.projects_by_pod_targets
            pods_project = pod_generator_result.project
            projects = projects_by_pod_targets.keys
            banana_project = projects.find { |p| p.project_name == 'BananaLib' }
            banana_project.should.be.not.nil
            banana_group = banana_project.group_for_spec('BananaLib')
            banana_group.files.map(&:name).sort.should == [
              'Banana.h',
              'Banana.m',
              'BananaPrivate.h',
              'BananaTrace.d',
              'MoreBanana.h',
            ]

            monkey_project = projects.find { |p| p.project_name == 'monkey' }
            monkey_project.should.not.be.nil
            monkey_group = monkey_project.group_for_spec('monkey')
            monkey_group.files.map(&:name).sort.should.be.empty # pre-built pod

            orange_project = projects.find { |p| p.project_name == 'OrangeFramework' }
            orange_project.should.not.be.nil
            organge_framework_group = orange_project.group_for_spec('OrangeFramework')
            organge_framework_group.files.map(&:name).sort.should. == [
              'Juicer.swift',
            ]

            coconut_project = projects.find { |p| p.project_name == 'CoconutLib' }
            coconut_project.should.not.be.nil
            coconut_group = coconut_project.group_for_spec('CoconutLib')
            coconut_group.files.map(&:name).sort.should == [
              'Coconut.h',
              'Coconut.m',
            ]

            # Verify all projects exist under Pods.xcodeproj
            pods_project.reference_for_path(banana_project.path).should.not.be.nil
            pods_project.reference_for_path(monkey_project.path).should.not.be.nil
            pods_project.reference_for_path(orange_project.path).should.not.be.nil
            pods_project.reference_for_path(coconut_project.path).should.not.be.nil
          end

          it 'installs the correct targets per project' do
            pod_generator_result = @generator.generate!
            pods_project = pod_generator_result.project
            projects = pod_generator_result.projects_by_pod_targets.keys
            banana_project = projects.find { |p| p.project_name == 'BananaLib' }
            coconut_project = projects.find { |p| p.project_name == 'CoconutLib' }
            monkey_project = projects.find { |p| p.project_name == 'monkey' }
            orange_project = projects.find { |p| p.project_name == 'OrangeFramework' }
            watermelon_project = projects.find { |p| p.project_name == 'WatermelonLib' }
            banana_project.should.not.be.nil
            coconut_project.should.not.be.nil
            monkey_project.should.not.be.nil
            watermelon_project.should.not.be.nil
            orange_project.should.not.be.nil

            pods_project.targets.map(&:name).sort.should == [
              'Pods-SampleApp-iOS',
              'Pods-SampleApp-macOS',
            ]

            watermelon_project.targets.map(&:name).sort.should == [
              'AppHost-WatermelonLib-iOS-UI-Tests',
              'AppHost-WatermelonLib-iOS-Unit-Tests',
              'AppHost-WatermelonLib-macOS-UI-Tests',
              'AppHost-WatermelonLib-macOS-Unit-Tests',
              'WatermelonLib-iOS',
              'WatermelonLib-iOS-App',
              'WatermelonLib-iOS-UI-UITests',
              'WatermelonLib-iOS-Unit-SnapshotTests',
              'WatermelonLib-iOS-Unit-Tests',
              'WatermelonLib-iOS-WatermelonLibExampleAppResources',
              'WatermelonLib-iOS-WatermelonLibTestResources',
              'WatermelonLib-macOS',
              'WatermelonLib-macOS-App',
              'WatermelonLib-macOS-UI-UITests',
              'WatermelonLib-macOS-Unit-SnapshotTests',
              'WatermelonLib-macOS-Unit-Tests',
              'WatermelonLib-macOS-WatermelonLibExampleAppResources',
              'WatermelonLib-macOS-WatermelonLibTestResources',
            ]

            banana_project.targets.map(&:name).sort.should == [
              'BananaLib-iOS',
              'BananaLib-macOS',
            ]

            coconut_project.targets.map(&:name).sort.should == [
              'CoconutLib-iOS',
              'CoconutLib-iOS-Unit-Tests',
              'CoconutLib-macOS',
              'CoconutLib-macOS-Unit-Tests',
            ]

            orange_project.targets.map(&:name).sort.should == [
              'OrangeFramework',
            ]

            monkey_project.targets.map(&:name).sort.should == [
              'monkey-iOS',
              'monkey-macOS',
            ]
          end

          it 'installs dependencies for app specs' do
            pod_generator_result = @generator.generate!
            projects = pod_generator_result.projects_by_pod_targets.keys
            grapefruits_project = projects.find { |p| p.project_name == 'GrapefruitsLib' }
            grapefruits_project.main_group['Dependencies'].find_file_by_path('BananaLib.xcodeproj').should.not.be.nil
          end

          it 'sets the pod and aggregate target dependencies' do
            pod_generator_result = @generator.generate!
            pods_project = pod_generator_result.project
            projects = pod_generator_result.projects_by_pod_targets.keys
            banana_project = projects.find { |p| p.project_name == 'BananaLib' }
            coconut_project = projects.find { |p| p.project_name == 'CoconutLib' }
            monkey_project = projects.find { |p| p.project_name == 'monkey' }
            banana_project.should.not.be.nil
            coconut_project.should.not.be.nil
            monkey_project.should.not.be.nil

            banana_project.targets.find { |t| t.name == 'BananaLib-iOS' }.dependencies.should.be.empty
            banana_project.targets.find { |t| t.name == 'BananaLib-macOS' }.dependencies.should.be.empty
            coconut_project.targets.find { |t| t.name == 'CoconutLib-macOS' }.dependencies.should.be.empty
            monkey_project.targets.find { |t| t.name == 'monkey-iOS' }.dependencies.should.be.empty
            monkey_project.targets.find { |t| t.name == 'monkey-macOS' }.dependencies.should.be.empty
            coconut_project.targets.find { |t| t.name == 'CoconutLib-iOS' }.dependencies.map(&:name).sort.should == [
              'OrangeFramework',
            ]
            pods_project.targets.find { |t| t.name == 'Pods-SampleApp-iOS' }.dependencies.map(&:name).sort.should == %w(
              BananaLib-iOS
              CoconutLib-iOS
              GrapefruitsLib-iOS
              OrangeFramework
              PineappleLib-iOS
              WatermelonLib-iOS
              monkey-iOS
            )
            pods_project.targets.find { |t| t.name == 'Pods-SampleApp-macOS' }.dependencies.map(&:name).sort.should == %w(
              BananaLib-macOS
              CoconutLib-macOS
              WatermelonLib-macOS
              monkey-macOS
            )
          end

          it 'adds no system frameworks to static targets' do
            pod_generator_result = @generator.generate!
            orange_project = pod_generator_result.projects_by_pod_targets.keys.find { |p| p.path.basename.to_s == 'OrangeFramework.xcodeproj' }
            orange_project.should.not.be.nil
            orange_project.targets.find { |t| t.name == 'OrangeFramework' }.frameworks_build_phase.file_display_names.should == []
          end

          it 'adds system frameworks to dynamic targets' do
            @orangeframework_pod_target.stubs(:build_type => BuildType.dynamic_framework)
            pod_generator_result = @generator.generate!
            orange_project = pod_generator_result.projects_by_pod_targets.keys.find { |p| p.path.basename.to_s == 'OrangeFramework.xcodeproj' }
            orange_project.should.not.be.nil
            orange_project.targets.find { |t| t.name == 'OrangeFramework' }.frameworks_build_phase.file_display_names.should == %w(
              Foundation.framework
              UIKit.framework
            )
          end

          it 'adds target dependencies when inheriting search paths' do
            inherited_target_definition = fixture_target_definition('SampleApp-iOS-Tests', @ios_platform)
            inherited_target = fixture_aggregate_target([], BuildType.static_library,
                                                        @ios_target.user_build_configurations, [], @ios_target.platform,
                                                        inherited_target_definition)
            inherited_target.search_paths_aggregate_targets << @ios_target
            @generator.aggregate_targets << inherited_target
            pod_generator_result = @generator.generate!
            pod_generator_result.project.targets.find { |t| t.name == 'Pods-SampleApp-iOS-Tests' }.dependencies.map(&:name).sort.should == [
              'Pods-SampleApp-iOS',
            ]
          end

          it 'sets resource bundle target dependencies' do
            @banana_spec.resource_bundles = { 'BananaLibResourcesBundle' => 'Resources/logo-sidebar.png' }
            pod_generator_result = @generator.generate!
            banana_project = pod_generator_result.projects_by_pod_targets.keys.find { |p| p.path.basename.to_s == 'BananaLib.xcodeproj' }
            banana_project.should.not.be.nil
            banana_project.targets.find { |t| t.name == 'BananaLib-iOS-BananaLibResourcesBundle' }.should.not.be.nil
            banana_project.targets.find { |t| t.name == 'BananaLib-macOS-BananaLibResourcesBundle' }.should.not.be.nil
            banana_project.targets.find { |t| t.name == 'BananaLib-iOS' }.dependencies.map(&:name).should == [
              'BananaLib-iOS-BananaLibResourcesBundle',
            ]
            banana_project.targets.find { |t| t.name == 'BananaLib-macOS' }.dependencies.map(&:name).should == [
              'BananaLib-macOS-BananaLibResourcesBundle',
            ]
          end

          it 'sets test resource bundle dependencies' do
            @coconut_test_spec.resource_bundles = { 'CoconutLibTestResourcesBundle' => 'Coconut.h' }
            pod_generator_result = @generator.generate!
            coconut_project = pod_generator_result.projects_by_pod_targets.keys.find { |p| p.path.basename.to_s == 'CoconutLib.xcodeproj' }
            coconut_project.should.not.be.nil
            coconut_project.targets.find { |t| t.name == 'CoconutLib-iOS-CoconutLibTestResourcesBundle' }.should.not.be.nil
            coconut_project.targets.find { |t| t.name == 'CoconutLib-macOS-CoconutLibTestResourcesBundle' }.should.not.be.nil
            coconut_project.targets.find { |t| t.name == 'CoconutLib-iOS-Unit-Tests' }.dependencies.map(&:name).sort.should == [
              'CoconutLib-iOS',
              'CoconutLib-iOS-CoconutLibTestResourcesBundle',
            ]
            coconut_project.targets.find { |t| t.name == 'CoconutLib-macOS-Unit-Tests' }.dependencies.map(&:name).sort.should == [
              'CoconutLib-macOS',
              'CoconutLib-macOS-CoconutLibTestResourcesBundle',
            ]
          end

          it 'sets the app host dependency for the tests that need it' do
            @coconut_test_spec.ios.requires_app_host = true
            pod_generator_result = @generator.generate!
            coconut_project = pod_generator_result.projects_by_pod_targets.keys.find { |p| p.path.basename.to_s == 'CoconutLib.xcodeproj' }
            coconut_project.should.not.be.nil
            coconut_project.targets.find { |t| t.name == 'AppHost-CoconutLib-iOS-Unit-Tests' }.should.not.be.nil
            coconut_project.targets.find { |t| t.name == 'CoconutLib-iOS-Unit-Tests' }.dependencies.map(&:name).sort.should == [
              'AppHost-CoconutLib-iOS-Unit-Tests',
              'CoconutLib-iOS',
            ]
            coconut_project.targets.find { |t| t.name == 'AppHost-CoconutLib-macOS-Unit-Tests' }.should.be.nil
            coconut_project.targets.find { |t| t.name == 'CoconutLib-macOS-Unit-Tests' }.dependencies.map(&:name).should == [
              'CoconutLib-macOS',
            ]
          end

          it 'sets the app host app spec dependency for the tests that need it' do
            @coconut_test_spec.ios.requires_app_host = true
            @coconut_test_spec.ios.app_host_name = @grapefruits_app_spec.name
            @coconut_ios_pod_target.test_app_hosts_by_spec = { @coconut_test_spec => [@grapefruits_app_spec, @grapefruits_ios_pod_target] }
            pod_generator_result = @generator.generate!
            coconut_project = pod_generator_result.projects_by_pod_targets.keys.find { |p| p.path.basename.to_s == 'CoconutLib.xcodeproj' }
            coconut_project.should.not.be.nil
            coconut_project.targets.find { |t| t.name == 'AppHost-CoconutLib-iOS-Unit-Tests' }.should.be.nil
            coconut_project.targets.find { |t| t.name == 'CoconutLib-iOS-Unit-Tests' }.dependencies.map(&:name).sort.should == [
              'CoconutLib-iOS',
              'GrapefruitsLib-iOS-App',
            ]
            coconut_project.targets.find { |t| t.name == 'AppHost-CoconutLib-macOS-Unit-Tests' }.should.be.nil
            coconut_project.targets.find { |t| t.name == 'CoconutLib-macOS-Unit-Tests' }.dependencies.map(&:name).should == [
              'CoconutLib-macOS',
            ]
          end

          it 'raises when a test spec has an app_host_name with requires_app_host = false' do
            @coconut_test_spec.ios.requires_app_host = false
            @coconut_test_spec.ios.app_host_name = @grapefruits_app_spec.name + '/Foo'
            -> { @generator.generate! }.should.raise(Informative).
              message.should.include '`CoconutLib-iOS-unit-Tests` manually specifies an app host but has not specified `requires_app_host = true`.'
          end

          it 'adds framework file references for framework pod targets that require building' do
            @orangeframework_pod_target.stubs(:build_type => BuildType.dynamic_framework)
            @coconut_ios_pod_target.stubs(:build_type => BuildType.dynamic_framework)
            @coconut_ios_pod_target.stubs(:should_build?).returns(true)
            pod_generator_result = @generator.generate!
            coconut_project = pod_generator_result.projects_by_pod_targets.keys.find { |p| p.path.basename.to_s == 'CoconutLib.xcodeproj' }
            coconut_project.should.not.be.nil
            native_target = coconut_project.targets.find { |t| t.name == 'CoconutLib-iOS' }
            native_target.isa.should == 'PBXNativeTarget'
            native_target.frameworks_build_phase.file_display_names.sort.should == [
              'Foundation.framework',
              'OrangeFramework.framework',
            ]
          end

          it 'adds dependency project references' do
            pod_generator_result = @generator.generate!
            coconut_project = pod_generator_result.projects_by_pod_targets.keys.find { |p| p.path.basename.to_s == 'CoconutLib.xcodeproj' }
            coconut_project.should.not.be.nil
            coconut_project.main_group['Dependencies'].find_file_by_path('OrangeFramework.xcodeproj').should.not.be.nil
          end

          it 'generates a different project name if the pod target has one specified' do
            @coconut_ios_pod_target.stubs(:project_name => 'CustomProjectName')
            pod_generator_result = @generator.generate!
            coconut_project = pod_generator_result.projects_by_pod_targets.keys.find { |p| p.path.basename.to_s == 'CustomProjectName.xcodeproj' }
            coconut_project.should.not.be.nil
          end

          it 'adds dependency project references for pods with custom project names' do
            @orangeframework_pod_target.stubs(:project_name => 'OrangeFrameworkCustomProjectName')
            pod_generator_result = @generator.generate!
            coconut_project = pod_generator_result.projects_by_pod_targets.keys.find { |p| p.path.basename.to_s == 'CoconutLib.xcodeproj' }
            coconut_project.should.not.be.nil
            coconut_project.main_group['Dependencies'].find_file_by_path('OrangeFrameworkCustomProjectName.xcodeproj').should.not.be.nil
          end

          it 'does not add framework references for framework pod targets that do not require building' do
            @orangeframework_pod_target.stubs(:build_type => BuildType.dynamic_framework)
            @coconut_ios_pod_target.stubs(:build_type => BuildType.dynamic_framework)
            @coconut_ios_pod_target.stubs(:should_build?).returns(false)
            pod_generator_result = @generator.generate!
            coconut_project = pod_generator_result.projects_by_pod_targets.keys.find { |p| p.path.basename.to_s == 'CoconutLib.xcodeproj' }
            coconut_project.should.not.be.nil
            coconut_project.targets.find { |t| t.name == 'CoconutLib-iOS' }.isa.should == 'PBXAggregateTarget'
          end

          it 'creates and links app host with an iOS test native target' do
            pod_generator_result = @generator.generate!
            watermelon_project = pod_generator_result.projects_by_pod_targets.keys.find { |p| p.path.basename.to_s == 'WatermelonLib.xcodeproj' }
            watermelon_project.should.not.be.nil
            app_host_target = watermelon_project.targets.find { |t| t.name == 'AppHost-WatermelonLib-iOS-Unit-Tests' }
            app_host_target.name.should.not.be.nil
            app_host_target.symbol_type.should == :application
            test_native_target = watermelon_project.targets.find { |t| t.name == 'WatermelonLib-iOS-Unit-SnapshotTests' }
            test_native_target.should.not.be.nil
            test_native_target.build_configurations.each do |bc|
              bc.build_settings['TEST_HOST'].should == '$(BUILT_PRODUCTS_DIR)/AppHost-WatermelonLib-iOS-Unit-Tests.app/AppHost-WatermelonLib-iOS-Unit-Tests'
            end
            watermelon_project.root_object.attributes['TargetAttributes'][test_native_target.uuid.to_s].should == {
              'TestTargetID' => app_host_target.uuid.to_s,
            }
          end

          it 'creates and links app host with an OSX test native target' do
            pod_generator_result = @generator.generate!
            watermelon_project = pod_generator_result.projects_by_pod_targets.keys.find { |p| p.path.basename.to_s == 'WatermelonLib.xcodeproj' }
            watermelon_project.should.not.be.nil
            app_host_target = watermelon_project.targets.find { |t| t.name == 'AppHost-WatermelonLib-macOS-Unit-Tests' }
            app_host_target.name.should.not.be.nil
            app_host_target.symbol_type.should == :application
            test_native_target = watermelon_project.targets.find { |t| t.name == 'WatermelonLib-macOS-Unit-SnapshotTests' }
            test_native_target.should.not.be.nil
            test_native_target.build_configurations.each do |bc|
              bc.build_settings['TEST_HOST'].should == '$(BUILT_PRODUCTS_DIR)/AppHost-WatermelonLib-macOS-Unit-Tests.app/Contents/MacOS/AppHost-WatermelonLib-macOS-Unit-Tests'
            end
            watermelon_project.root_object.attributes['TargetAttributes'][test_native_target.uuid.to_s].should == {
              'TestTargetID' => app_host_target.uuid.to_s,
            }
          end

          it "uses the user project's object version for the all projects" do
            tmp_directory = Pathname(Dir.tmpdir) + 'CocoaPods'
            FileUtils.mkdir_p(tmp_directory)
            proj = Xcodeproj::Project.new(tmp_directory + 'Yolo.xcodeproj', false, 51)
            proj.save

            user_target = stub('SampleApp-iOS-User-Target', :symbol_type => :application)

            target = AggregateTarget.new(config.sandbox, BuildType.static_library,
                                         { 'App Store' => :release, 'Debug' => :debug, 'Release' => :release, 'Test' => :debug },
                                         [], Platform.new(:ios, '6.0'), fixture_target_definition,
                                         config.sandbox.root.dirname, proj, nil, {})

            target.stubs(:user_targets).returns([user_target])

            @generator = MultiPodsProjectGenerator.new(config.sandbox, [target], [],
                                                       @analysis_result.all_user_build_configurations, @installation_options, config, 51)
            pod_generator_result = @generator.generate!
            pod_generator_result.project.object_version.should == '51'
            pod_generator_result.projects_by_pod_targets.keys.each do |target_project|
              target_project.object_version.should == '51'
            end

            FileUtils.rm_rf(tmp_directory)
          end

          it 'allows generating a Pods project with an empty list of aggregate targets' do
            @generator = MultiPodsProjectGenerator.new(config.sandbox, [], [], @analysis_result.all_user_build_configurations,
                                                       @installation_options, config, '1')
            @generator.expects(:create_container_project).returns(Pod::Project.any_instance)
            @generator.generate!
          end

          it 'will not create container project for nil parameter to aggregate targets' do
            @generator = MultiPodsProjectGenerator.new(config.sandbox, nil, [@monkey_ios_pod_target], @analysis_result.all_user_build_configurations,
                                                       @installation_options, config, 51)
            @generator.expects(:create_container_project).returns(nil)
            @generator.generate!
          end

          describe '#write' do
            before do
              Xcodeproj::Project.any_instance.stubs(:recreate_user_schemes)
              Xcodeproj::Project.any_instance.stubs(:save)
            end

            it 'recursively sorts the project' do
              pod_generator_result = @generator.generate!
              pods_project = pod_generator_result.project
              pods_project.main_group.expects(:sort)
              pod_generator_result.projects_by_pod_targets.keys.each do |target_project|
                target_project.main_group.expects(:sort)
              end
              generated_projects = [pods_project] + pod_generator_result.projects_by_pod_targets.keys
              Xcode::PodsProjectWriter.new(@generator.sandbox, generated_projects,
                                           pod_generator_result.target_installation_results.pod_target_installation_results,
                                           @generator.installation_options).write!
            end

            it 'saves the project' do
              pod_generator_result = @generator.generate!
              Xcodeproj::Project.any_instance.stubs(:recreate_user_schemes)
              pods_project = pod_generator_result.project
              projects_by_pod_targets = pod_generator_result.projects_by_pod_targets
              pods_project.expects(:save)
              projects_by_pod_targets.keys.each do |target_project|
                target_project.expects(:sort)
              end
              generated_projects = [pods_project] + projects_by_pod_targets.keys
              Xcode::PodsProjectWriter.new(@generator.sandbox, generated_projects,
                                           pod_generator_result.target_installation_results.pod_target_installation_results,
                                           @generator.installation_options).write!
            end

            it 'project cleans up empty groups' do
              @generator.sandbox.store_local_path('BananaLib', fixture('banana-lib/BananaLib.podspec'))
              pod_generator_result = @generator.generate!
              pods_project = pod_generator_result.project
              projects_by_pod_targets = pod_generator_result.projects_by_pod_targets
              generated_projects = [pods_project] + projects_by_pod_targets.keys
              Xcode::PodsProjectWriter.new(@generator.sandbox, generated_projects,
                                           pod_generator_result.target_installation_results.pod_target_installation_results,
                                           @generator.installation_options).write!
              pods_project.main_group['Pods'].should.not.be.nil
              pods_project.main_group['Development Pods'].should.not.be.nil
              pods_project.main_group['Dependencies'].should.be.nil

              projects_by_pod_targets.keys.each do |project|
                project.main_group['Pods'].should.be.nil
                project.main_group['Development Pods'].should.be.nil
              end
            end
          end

          describe '#share_development_pod_schemes' do
            it 'does not share by default' do
              pod_generator_result = @generator.generate!
              @generator.sandbox.stubs(:development_pods).returns('BananaLib' => fixture('BananaLib'))
              Xcodeproj::XCScheme.expects(:share_scheme).never
              project = pod_generator_result.projects_by_pod_targets.keys.find { |p| p.project_name == 'BananaLib' }
              @generator.configure_schemes(project, pod_generator_result.projects_by_pod_targets[project], pod_generator_result)
            end

            it 'can share all schemes' do
              @generator.installation_options.
                  stubs(:share_schemes_for_development_pods).
                  returns(true)

              pod_generator_result = @generator.generate!
              @generator.sandbox.stubs(:development_pods).returns('BananaLib' => fixture('BananaLib'))
              project_by_target_map = pod_generator_result.projects_by_pod_targets
              banana_project = project_by_target_map.keys.find { |p| p.project_name == 'BananaLib' }
              banana_project.should.not.be.nil

              Xcodeproj::XCScheme.expects(:share_scheme).with(
                banana_project.path,
                'BananaLib-iOS')

              Xcodeproj::XCScheme.expects(:share_scheme).with(
                banana_project.path,
                'BananaLib-macOS')

              banana_development_pods = project_by_target_map[banana_project].select { |pod_target| @generator.sandbox.local?(pod_target.pod_name) }
              @generator.configure_schemes(banana_project, banana_development_pods, pod_generator_result)
            end

            it 'shares test schemes' do
              @generator.installation_options.
                  stubs(:share_schemes_for_development_pods).
                  returns(true)
              @generator.sandbox.stubs(:development_pods).returns('CoconutLib' => fixture('CoconutLib'))

              pod_generator_result = @generator.generate!
              projects_by_pod_targets = pod_generator_result.projects_by_pod_targets
              coconut_project = projects_by_pod_targets.keys.find { |p| p.path.basename.to_s == 'CoconutLib.xcodeproj' }
              coconut_project.should.not.be.nil

              Xcodeproj::XCScheme.expects(:share_scheme).with(
                coconut_project.path,
                'CoconutLib-iOS')

              Xcodeproj::XCScheme.expects(:share_scheme).with(
                coconut_project.path,
                'CoconutLib-iOS-Unit-Tests')

              Xcodeproj::XCScheme.expects(:share_scheme).with(
                coconut_project.path,
                'CoconutLib-macOS')

              Xcodeproj::XCScheme.expects(:share_scheme).with(
                coconut_project.path,
                'CoconutLib-macOS-Unit-Tests')

              @generator.configure_schemes(coconut_project, projects_by_pod_targets[coconut_project], pod_generator_result)
            end

            it 'correctly configures schemes for all specs' do
              @coconut_spec.scheme = { :launch_arguments => ['Arg1'] }
              @coconut_test_spec.scheme = { :launch_arguments => ['TestArg1'],
                                            :environment_variables => { 'Key1' => 'Val1' },
                                            :code_coverage => true }
              @generator.installation_options.
                  stubs(:share_schemes_for_development_pods).
                  returns(true)
              @generator.sandbox.stubs(:development_pods).returns('CoconutLib' => fixture('CoconutLib'))

              pod_generator_result = @generator.generate!

              projects_by_pod_targets = pod_generator_result.projects_by_pod_targets
              coconut_project = projects_by_pod_targets.keys.find { |p| p.project_name == 'CoconutLib' }

              Xcode::PodsProjectWriter.new(config.sandbox, [coconut_project],
                                           pod_generator_result.target_installation_results.pod_target_installation_results,
                                           @generator.installation_options).write!

              @generator.configure_schemes(coconut_project, pod_generator_result.projects_by_pod_targets[coconut_project], pod_generator_result)

              scheme_path = Xcodeproj::XCScheme.shared_data_dir(coconut_project.path) + 'CoconutLib-iOS.xcscheme'
              scheme = Xcodeproj::XCScheme.new(scheme_path)
              scheme.launch_action.command_line_arguments.all_arguments.map(&:to_h).should == [
                { :argument => 'Arg1', :enabled => true },
              ]
              test_scheme_path = Xcodeproj::XCScheme.shared_data_dir(coconut_project.path) + 'CoconutLib-iOS-Unit-Tests.xcscheme'
              test_scheme = Xcodeproj::XCScheme.new(test_scheme_path)
              test_scheme.launch_action.command_line_arguments.all_arguments.map(&:to_h).should == [
                { :argument => 'TestArg1', :enabled => true },
              ]
              test_scheme.launch_action.environment_variables.all_variables.map(&:to_h).should == [
                { :key => 'Key1', :value => 'Val1', :enabled => true },
              ]
              test_scheme.test_action.code_coverage_enabled?.should.be.true
              test_scheme.launch_action.macro_expansions.empty?.should.be.false
            end

            it 'adds the test bundle to the test action of the app host when using app specs' do
              @generator.installation_options.
                  stubs(:share_schemes_for_development_pods).
                  returns(true)
              @generator.sandbox.stubs(:development_pods).returns('PineappleLib' => fixture('pineapple-lib'))

              pod_generator_result = @generator.generate!

              projects_by_pod_targets = pod_generator_result.projects_by_pod_targets
              pineapple_project = projects_by_pod_targets.keys.find { |p| p.project_name == 'PineappleLib' }

              Xcode::PodsProjectWriter.new(config.sandbox, [pineapple_project],
                                           pod_generator_result.target_installation_results.pod_target_installation_results,
                                           @generator.installation_options).write!

              @generator.configure_schemes(pineapple_project, pod_generator_result.projects_by_pod_targets[pineapple_project], pod_generator_result)

              scheme_path = Xcodeproj::XCScheme.shared_data_dir(pineapple_project.path) + 'PineappleLib-iOS.xcscheme'
              scheme_path.should.exist?
              test_scheme_path = Xcodeproj::XCScheme.shared_data_dir(pineapple_project.path) + 'PineappleLib-iOS-Unit-Tests.xcscheme'
              test_scheme = Xcodeproj::XCScheme.new(test_scheme_path)
              test_scheme.launch_action.macro_expansions.should.not.be.empty?

              host_scheme_path = Xcodeproj::XCScheme.shared_data_dir(pineapple_project.path) + 'PineappleLib-iOS-App.xcscheme'
              host_scheme = Xcodeproj::XCScheme.new(host_scheme_path)
              native_target_uuids = @pineapple_spec.test_specs.
                  map { |test_spec| pod_generator_result.native_target_for_spec(test_spec).uuid }.
                  sort
              host_scheme.test_action.testables.flat_map { |t| t.buildable_references.map(&:target_uuid) }.sort.should == native_target_uuids
            end

            it 'allows opting out' do
              @generator.installation_options.
                  stubs(:share_schemes_for_development_pods).
                  returns(false)
              pod_generator_result = @generator.generate!
              @generator.sandbox.stubs(:development_pods).returns('BananaLib' => fixture('BananaLib'))

              project = pod_generator_result.projects_by_pod_targets.keys.find { |p| p.project_name == 'BananaLib' }

              Xcodeproj::XCScheme.expects(:share_scheme).never
              @generator.configure_schemes(project, pod_generator_result.projects_by_pod_targets[project], pod_generator_result)

              @generator.installation_options.
                  stubs(:share_schemes_for_development_pods).
                  returns(nil)

              Xcodeproj::XCScheme.expects(:share_scheme).never
              @generator.configure_schemes(project, pod_generator_result.projects_by_pod_targets[project], pod_generator_result)
            end

            it 'allows specifying strings of pods to share' do
              @generator.installation_options.
                  stubs(:share_schemes_for_development_pods).
                  returns(%w(BananaLib))

              pod_generator_result = @generator.generate!
              @generator.sandbox.stubs(:development_pods).returns('BananaLib' => fixture('BananaLib'), 'PineappleLib' => fixture('pineapple-lib'))
              project_by_pod_targets = pod_generator_result.projects_by_pod_targets
              banana_project_result = project_by_pod_targets.keys.select { |p| p.path.basename.to_s == 'BananaLib.xcodeproj' }
              banana_project_result.count.should == 1
              banana_project = banana_project_result.first

              Xcodeproj::XCScheme.expects(:share_scheme).with(
                banana_project.path,
                'BananaLib-iOS')

              Xcodeproj::XCScheme.expects(:share_scheme).with(
                banana_project.path,
                'BananaLib-macOS')

              @generator.configure_schemes(banana_project, project_by_pod_targets[banana_project], pod_generator_result)

              @generator.installation_options.
                  stubs(:share_schemes_for_development_pods).
                  returns(%w(orange-framework))

              orange_project = project_by_pod_targets.keys.find { |p| p.path.basename.to_s == 'OrangeFramework.xcodeproj' }
              orange_project.should.not.be.nil
              Xcodeproj::XCScheme.expects(:share_scheme).never
              @generator.configure_schemes(orange_project, project_by_pod_targets[orange_project], pod_generator_result)
            end
          end
        end
      end
    end
  end
end
