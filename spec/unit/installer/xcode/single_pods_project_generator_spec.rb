require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  class Installer
    class Xcode
      describe SinglePodsProjectGenerator do
        describe 'Generating Pods Project' do
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

            @generator = SinglePodsProjectGenerator.new(config.sandbox, aggregate_targets, pod_targets,
                                                        @analysis_result.all_user_build_configurations,
                                                        @installation_options, config, nil)

            Pod::Installer::Xcode::PodsProjectGenerator::TargetInstallerHelper.stubs(:update_changed_file)
          end

          it "creates build configurations for all of the user's targets" do
            pod_generator_result = @generator.generate!
            pod_generator_result.project.build_configurations.map(&:name).sort.should == ['App Store', 'Debug', 'Release', 'Test']
          end

          it 'sets STRIP_INSTALLED_PRODUCT to NO for all configurations for the whole project' do
            pod_generator_result = @generator.generate!
            pod_generator_result.project.build_settings('Debug')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
            pod_generator_result.project.build_settings('Test')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
            pod_generator_result.project.build_settings('Release')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
            pod_generator_result.project.build_settings('App Store')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
          end

          it 'sets the SYMROOT to the default value for all configurations for the whole project' do
            pod_generator_result = @generator.generate!
            pod_generator_result.project.build_settings('Debug')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
            pod_generator_result.project.build_settings('Test')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
            pod_generator_result.project.build_settings('Release')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
            pod_generator_result.project.build_settings('App Store')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
          end

          it 'creates the correct Pods project' do
            pod_generator_result = @generator.generate!
            pod_generator_result.project.class.should == Pod::Project
          end

          it 'adds the Podfile to the Pods project' do
            config.stubs(:podfile_path).returns(Pathname.new('/Podfile'))
            pod_generator_result = @generator.generate!
            pod_generator_result.project['Podfile'].should.be.not.nil
          end

          it 'sets the deployment target for the whole project' do
            pod_generator_result = @generator.generate!
            build_settings = pod_generator_result.project.build_configurations.map(&:build_settings)
            build_settings.each do |build_setting|
              build_setting['MACOSX_DEPLOYMENT_TARGET'].should == '10.8'
              build_setting['IPHONEOS_DEPLOYMENT_TARGET'].should == '6.0'
            end
          end

          it 'installs file references' do
            pod_generator_result = @generator.generate!
            banana_group = pod_generator_result.project.group_for_spec('BananaLib')
            banana_group.files.map(&:name).sort.should == [
              'Banana.h',
              'Banana.m',
              'BananaPrivate.h',
              'BananaTrace.d',
              'MoreBanana.h',
            ]
            monkey_group = pod_generator_result.project.group_for_spec('monkey')
            monkey_group.files.map(&:name).sort.should.be.empty # pre-built pod
            organge_framework_group = pod_generator_result.project.group_for_spec('OrangeFramework')
            organge_framework_group.files.map(&:name).sort.should. == [
              'Juicer.swift',
            ]
            coconut_group = pod_generator_result.project.group_for_spec('CoconutLib')
            coconut_group.files.map(&:name).sort.should == [
              'Coconut.h',
              'Coconut.m',
            ]
          end

          it 'installs the correct targets in the project' do
            pod_generator_result = @generator.generate!
            pod_generator_result.project.targets.map(&:name).sort.should == [
              'AppHost-WatermelonLib-iOS-UI-Tests',
              'AppHost-WatermelonLib-iOS-Unit-Tests',
              'AppHost-WatermelonLib-macOS-UI-Tests',
              'AppHost-WatermelonLib-macOS-Unit-Tests',
              'BananaLib-iOS',
              'BananaLib-macOS',
              'CoconutLib-iOS',
              'CoconutLib-iOS-Unit-Tests',
              'CoconutLib-macOS',
              'CoconutLib-macOS-Unit-Tests',
              'GrapefruitsLib-iOS',
              'GrapefruitsLib-iOS-App',
              'OrangeFramework',
              'PineappleLib-iOS',
              'PineappleLib-iOS-App',
              'PineappleLib-iOS-UI-UI',
              'PineappleLib-iOS-Unit-Tests',
              'Pods-SampleApp-iOS',
              'Pods-SampleApp-macOS',
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
              'monkey-iOS',
              'monkey-macOS',
            ]
          end

          it 'sets the pod and aggregate target dependencies' do
            pod_generator_result = @generator.generate!
            pod_generator_result.project.targets.find { |t| t.name == 'BananaLib-iOS' }.dependencies.should.be.empty
            pod_generator_result.project.targets.find { |t| t.name == 'BananaLib-macOS' }.dependencies.should.be.empty
            pod_generator_result.project.targets.find { |t| t.name == 'CoconutLib-macOS' }.dependencies.should.be.empty
            pod_generator_result.project.targets.find { |t| t.name == 'monkey-iOS' }.dependencies.should.be.empty
            pod_generator_result.project.targets.find { |t| t.name == 'monkey-macOS' }.dependencies.should.be.empty
            pod_generator_result.project.targets.find { |t| t.name == 'CoconutLib-iOS' }.dependencies.map(&:name).sort.should == [
              'OrangeFramework',
            ]
            pod_generator_result.project.targets.find { |t| t.name == 'Pods-SampleApp-iOS' }.dependencies.map(&:name).sort.should == %w(
              BananaLib-iOS
              CoconutLib-iOS
              GrapefruitsLib-iOS
              OrangeFramework
              PineappleLib-iOS
              WatermelonLib-iOS
              monkey-iOS
            )
            pod_generator_result.project.targets.find { |t| t.name == 'Pods-SampleApp-macOS' }.dependencies.map(&:name).sort.should == %w(
              BananaLib-macOS
              CoconutLib-macOS
              WatermelonLib-macOS
              monkey-macOS
            )
          end

          it 'adds no system frameworks to static targets' do
            pod_generator_result = @generator.generate!
            pod_generator_result.project.targets.find { |t| t.name == 'OrangeFramework' }.frameworks_build_phase.file_display_names.should == []
          end

          it 'adds system frameworks to dynamic targets' do
            @orangeframework_pod_target.stubs(:build_type => BuildType.dynamic_framework)
            pod_generator_result = @generator.generate!
            pod_generator_result.project.targets.find { |t| t.name == 'OrangeFramework' }.frameworks_build_phase.file_display_names.should == %w(
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
            pod_generator_result.project.targets.find { |t| t.name == 'BananaLib-iOS-BananaLibResourcesBundle' }.should.not.be.nil
            pod_generator_result.project.targets.find { |t| t.name == 'BananaLib-macOS-BananaLibResourcesBundle' }.should.not.be.nil
            pod_generator_result.project.targets.find { |t| t.name == 'BananaLib-iOS' }.dependencies.map(&:name).should == [
              'BananaLib-iOS-BananaLibResourcesBundle',
            ]
            pod_generator_result.project.targets.find { |t| t.name == 'BananaLib-macOS' }.dependencies.map(&:name).should == [
              'BananaLib-macOS-BananaLibResourcesBundle',
            ]
          end

          it 'sets test resource bundle dependencies' do
            @coconut_test_spec.resource_bundles = { 'CoconutLibTestResourcesBundle' => 'Coconut.h' }
            pod_generator_result = @generator.generate!
            pod_generator_result.project.targets.find { |t| t.name == 'CoconutLib-iOS-CoconutLibTestResourcesBundle' }.should.not.be.nil
            pod_generator_result.project.targets.find { |t| t.name == 'CoconutLib-macOS-CoconutLibTestResourcesBundle' }.should.not.be.nil
            pod_generator_result.project.targets.find { |t| t.name == 'CoconutLib-iOS-Unit-Tests' }.dependencies.map(&:name).sort.should == [
              'CoconutLib-iOS',
              'CoconutLib-iOS-CoconutLibTestResourcesBundle',
            ]
            pod_generator_result.project.targets.find { |t| t.name == 'CoconutLib-macOS-Unit-Tests' }.dependencies.map(&:name).sort.should == [
              'CoconutLib-macOS',
              'CoconutLib-macOS-CoconutLibTestResourcesBundle',
            ]
          end

          it 'sets the app host dependency for the tests that need it' do
            @coconut_test_spec.ios.requires_app_host = true
            pod_generator_result = @generator.generate!
            pod_generator_result.project.targets.find { |t| t.name == 'AppHost-CoconutLib-iOS-Unit-Tests' }.should.not.be.nil
            pod_generator_result.project.targets.find { |t| t.name == 'CoconutLib-iOS-Unit-Tests' }.dependencies.map(&:name).sort.should == [
              'AppHost-CoconutLib-iOS-Unit-Tests',
              'CoconutLib-iOS',
            ]
            pod_generator_result.project.targets.find { |t| t.name == 'AppHost-CoconutLib-macOS-Unit-Tests' }.should.be.nil
            pod_generator_result.project.targets.find { |t| t.name == 'CoconutLib-macOS-Unit-Tests' }.dependencies.map(&:name).should == [
              'CoconutLib-macOS',
            ]
          end

          it 'sets the app host app spec dependency for the tests that need it' do
            @coconut_test_spec.ios.requires_app_host = true
            @coconut_test_spec.ios.app_host_name = @grapefruits_app_spec.name
            @coconut_ios_pod_target.test_app_hosts_by_spec = { @coconut_test_spec => [@grapefruits_app_spec, @grapefruits_ios_pod_target] }
            pod_generator_result = @generator.generate!
            coconut_project = pod_generator_result.project
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
            @orangeframework_pod_target.stubs(:build_type).returns(BuildType.dynamic_framework)
            @coconut_ios_pod_target.stubs(:build_type).returns(BuildType.dynamic_framework)
            @coconut_ios_pod_target.stubs(:should_build?).returns(true)
            pod_generator_result = @generator.generate!
            native_target = pod_generator_result.project.targets.find { |t| t.name == 'CoconutLib-iOS' }
            native_target.isa.should == 'PBXNativeTarget'
            native_target.frameworks_build_phase.file_display_names.sort.should == [
              'Foundation.framework',
              'OrangeFramework.framework',
            ]
          end

          it 'does not add framework references for framework pod targets that do not require building' do
            @orangeframework_pod_target.stubs(:build_type).returns(BuildType.dynamic_framework)
            @coconut_ios_pod_target.stubs(:build_type).returns(BuildType.dynamic_framework)
            @coconut_ios_pod_target.stubs(:should_build?).returns(false)
            pod_generator_result = @generator.generate!
            pod_generator_result.project.targets.find { |t| t.name == 'CoconutLib-iOS' }.isa.should == 'PBXAggregateTarget'
          end

          it 'creates and links app host with an iOS test native target' do
            pod_generator_result = @generator.generate!
            app_host_target = pod_generator_result.project.targets.find { |t| t.name == 'AppHost-WatermelonLib-iOS-Unit-Tests' }
            app_host_target.name.should.not.be.nil
            app_host_target.symbol_type.should == :application
            test_native_target = pod_generator_result.project.targets.find { |t| t.name == 'WatermelonLib-iOS-Unit-SnapshotTests' }
            test_native_target.should.not.be.nil
            test_native_target.build_configurations.each do |bc|
              bc.build_settings['TEST_HOST'].should == '$(BUILT_PRODUCTS_DIR)/AppHost-WatermelonLib-iOS-Unit-Tests.app/AppHost-WatermelonLib-iOS-Unit-Tests'
            end
            pod_generator_result.project.root_object.attributes['TargetAttributes'][test_native_target.uuid.to_s].should == {
              'TestTargetID' => app_host_target.uuid.to_s,
            }
          end

          it 'creates and links app host with an OSX test native target' do
            pod_generator_result = @generator.generate!
            app_host_target = pod_generator_result.project.targets.find { |t| t.name == 'AppHost-WatermelonLib-macOS-Unit-Tests' }
            app_host_target.name.should.not.be.nil
            app_host_target.symbol_type.should == :application
            test_native_target = pod_generator_result.project.targets.find { |t| t.name == 'WatermelonLib-macOS-Unit-SnapshotTests' }
            test_native_target.should.not.be.nil
            test_native_target.build_configurations.each do |bc|
              bc.build_settings['TEST_HOST'].should == '$(BUILT_PRODUCTS_DIR)/AppHost-WatermelonLib-macOS-Unit-Tests.app/Contents/MacOS/AppHost-WatermelonLib-macOS-Unit-Tests'
            end
            pod_generator_result.project.root_object.attributes['TargetAttributes'][test_native_target.uuid.to_s].should == {
              'TestTargetID' => app_host_target.uuid.to_s,
            }
          end

          it "uses the user project's object version for the pods project" do
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

            @generator = SinglePodsProjectGenerator.new(config.sandbox, [target], [],
                                                        @analysis_result.all_user_build_configurations,
                                                        @installation_options, config, 51)
            pod_generator_result = @generator.generate!
            pod_generator_result.project.object_version.should == '51'

            FileUtils.rm_rf(tmp_directory)
          end

          describe '#write' do
            it 'recursively sorts the project' do
              pod_generator_result = @generator.generate!
              pod_generator_result.project.main_group.expects(:sort)
              Xcodeproj::Project.any_instance.stubs(:recreate_user_schemes)
              Xcode::PodsProjectWriter.new(@generator.sandbox, [pod_generator_result.project],
                                           pod_generator_result.target_installation_results.pod_target_installation_results,
                                           @generator.installation_options).write!
            end

            it 'saves the project to the given path' do
              pod_generator_result = @generator.generate!
              Xcodeproj::Project.any_instance.stubs(:recreate_user_schemes)
              pod_generator_result.project.expects(:save)
              Xcode::PodsProjectWriter.new(@generator.sandbox, [pod_generator_result.project],
                                           pod_generator_result.target_installation_results.pod_target_installation_results,
                                           @generator.installation_options).write!
            end
          end

          describe '#share_development_pod_schemes' do
            it 'does not share by default' do
              pod_generator_result = @generator.generate!
              @generator.sandbox.stubs(:development_pods).returns('BananaLib' => fixture('BananaLib'))
              Xcodeproj::XCScheme.expects(:share_scheme).never
              targets = @generator.pod_targets.select { |target| target.root_spec.name == 'BananaLib' }
              @generator.configure_schemes(pod_generator_result.project, targets, pod_generator_result)
            end

            it 'can share all schemes' do
              @generator.installation_options.
                  stubs(:share_schemes_for_development_pods).
                  returns(true)

              pod_generator_result = @generator.generate!
              @generator.sandbox.stubs(:development_pods).returns('BananaLib' => fixture('BananaLib'))

              Xcodeproj::XCScheme.expects(:share_scheme).with(
                pod_generator_result.project.path,
                'BananaLib-iOS')

              Xcodeproj::XCScheme.expects(:share_scheme).with(
                pod_generator_result.project.path,
                'BananaLib-macOS')

              targets = @generator.pod_targets.select { |target| target.root_spec.name == 'BananaLib' }
              @generator.configure_schemes(pod_generator_result.project, targets, pod_generator_result)
            end

            it 'shares test schemes' do
              @generator.installation_options.
                  stubs(:share_schemes_for_development_pods).
                  returns(true)
              @generator.sandbox.stubs(:development_pods).returns('CoconutLib' => fixture('CoconutLib'))

              pod_generator_result = @generator.generate!

              Xcodeproj::XCScheme.expects(:share_scheme).with(
                pod_generator_result.project.path,
                'CoconutLib-iOS')

              Xcodeproj::XCScheme.expects(:share_scheme).with(
                pod_generator_result.project.path,
                'CoconutLib-iOS-Unit-Tests')

              Xcodeproj::XCScheme.expects(:share_scheme).with(
                pod_generator_result.project.path,
                'CoconutLib-macOS')

              Xcodeproj::XCScheme.expects(:share_scheme).with(
                pod_generator_result.project.path,
                'CoconutLib-macOS-Unit-Tests')

              targets = @generator.pod_targets.select { |target| target.root_spec.name == 'CoconutLib' }
              @generator.configure_schemes(pod_generator_result.project, targets, pod_generator_result)
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

              Xcode::PodsProjectWriter.new(config.sandbox, [pod_generator_result.project],
                                           pod_generator_result.target_installation_results.pod_target_installation_results,
                                           @generator.installation_options).write!

              @generator.configure_schemes(pod_generator_result.project, @generator.pod_targets, pod_generator_result)

              scheme_path = Xcodeproj::XCScheme.shared_data_dir(pod_generator_result.project.path) + 'CoconutLib-iOS.xcscheme'
              scheme = Xcodeproj::XCScheme.new(scheme_path)
              scheme.launch_action.command_line_arguments.all_arguments.map(&:to_h).should == [
                { :argument => 'Arg1', :enabled => true },
              ]
              test_scheme_path = Xcodeproj::XCScheme.shared_data_dir(pod_generator_result.project.path) + 'CoconutLib-iOS-Unit-Tests.xcscheme'
              test_scheme = Xcodeproj::XCScheme.new(test_scheme_path)
              test_scheme.launch_action.command_line_arguments.all_arguments.map(&:to_h).should == [
                { :argument => 'TestArg1', :enabled => true },
              ]
              test_scheme.launch_action.environment_variables.all_variables.map(&:to_h).should == [
                { :key => 'Key1', :value => 'Val1', :enabled => true },
              ]
              test_scheme.test_action.code_coverage_enabled?.should.be.true
            end

            it 'adds the test bundle to the test action of the app host when using app specs' do
              @generator.installation_options.
                  stubs(:share_schemes_for_development_pods).
                  returns(true)
              @generator.sandbox.stubs(:development_pods).returns('PineappleLib' => fixture('pineapple-lib'))

              pod_generator_result = @generator.generate!

              project = pod_generator_result.project

              Xcode::PodsProjectWriter.new(config.sandbox, [project],
                                           pod_generator_result.target_installation_results.pod_target_installation_results,
                                           @generator.installation_options).write!

              @generator.configure_schemes(project, @generator.pod_targets, pod_generator_result)

              scheme_path = Xcodeproj::XCScheme.shared_data_dir(project.path) + 'PineappleLib-iOS.xcscheme'
              scheme_path.should.exist?
              test_scheme_path = Xcodeproj::XCScheme.shared_data_dir(project.path) + 'PineappleLib-iOS-Unit-Tests.xcscheme'
              test_scheme = Xcodeproj::XCScheme.new(test_scheme_path)
              test_scheme.launch_action.macro_expansions.should.not.be.empty?

              host_scheme_path = Xcodeproj::XCScheme.shared_data_dir(project.path) + 'PineappleLib-iOS-App.xcscheme'
              host_scheme = Xcodeproj::XCScheme.new(host_scheme_path)
              native_target_uuids = @pineapple_spec.test_specs.
                  map { |test_spec| pod_generator_result.native_target_for_spec(test_spec).uuid }.
                  sort
              host_scheme.test_action.testables.flat_map { |t| t.buildable_references.map(&:target_uuid) }.sort.should == native_target_uuids
              test_scheme.launch_action.macro_expansions.empty?.should.be.false
            end

            it 'allows opting out' do
              @generator.installation_options.
                  stubs(:share_schemes_for_development_pods).
                  returns(false)

              pod_generator_result = @generator.generate!
              @generator.sandbox.stubs(:development_pods).returns('BananaLib' => fixture('BananaLib'))

              targets = @generator.pod_targets.select { |target| target.root_spec.name == 'BananaLib' }

              Xcode::PodsProjectWriter.new(config.sandbox, [pod_generator_result.project],
                                           pod_generator_result.target_installation_results.pod_target_installation_results,
                                           @generator.installation_options).write!

              Xcodeproj::XCScheme.expects(:share_scheme).never
              @generator.configure_schemes(pod_generator_result.project, targets, pod_generator_result)

              @generator.installation_options.
                  stubs(:share_schemes_for_development_pods).
                  returns(nil)

              Xcodeproj::XCScheme.expects(:share_scheme).never
              @generator.configure_schemes(pod_generator_result.project, targets, pod_generator_result)
            end

            it 'allows specifying strings of pods to share' do
              @generator.installation_options.
                  stubs(:share_schemes_for_development_pods).
                  returns(%w(BananaLib))

              pod_generator_result = @generator.generate!
              @generator.sandbox.stubs(:development_pods).returns('BananaLib' => fixture('BananaLib'), 'PineappleLib' => fixture('pineapple-lib'))

              Xcode::PodsProjectWriter.new(config.sandbox, [pod_generator_result.project],
                                           pod_generator_result.target_installation_results.pod_target_installation_results,
                                           @generator.installation_options).write!

              Xcodeproj::XCScheme.expects(:share_scheme).with(
                pod_generator_result.project.path,
                'BananaLib-iOS')

              Xcodeproj::XCScheme.expects(:share_scheme).with(
                pod_generator_result.project.path,
                'BananaLib-macOS')

              @generator.configure_schemes(pod_generator_result.project, @generator.pod_targets, pod_generator_result)

              @generator.installation_options.
                  stubs(:share_schemes_for_development_pods).
                  returns(%w(orange-framework))

              Xcodeproj::XCScheme.expects(:share_scheme).never
              @generator.configure_schemes(pod_generator_result.project, @generator.pod_targets, pod_generator_result)
            end

            it 'allows specifying regular expressions of pods to share' do
              @generator.installation_options.
                  stubs(:share_schemes_for_development_pods).
                  returns([/bAnaNalIb/i, /Ban*/])

              pod_generator_result = @generator.generate!
              @generator.sandbox.stubs(:development_pods).returns('BananaLib' => fixture('BananaLib'), 'PineappleLib' => fixture_spec('pineapple-lib/PineappleLib.podspec'))

              Xcode::PodsProjectWriter.new(config.sandbox, [pod_generator_result.project],
                                           pod_generator_result.target_installation_results.pod_target_installation_results,
                                           @generator.installation_options).write!

              Xcodeproj::XCScheme.expects(:share_scheme).with(
                pod_generator_result.project.path,
                'BananaLib-iOS')

              Xcodeproj::XCScheme.expects(:share_scheme).with(
                pod_generator_result.project.path,
                'BananaLib-macOS')

              @generator.configure_schemes(pod_generator_result.project, @generator.pod_targets, pod_generator_result)

              @generator.installation_options.
                  stubs(:share_schemes_for_development_pods).
                  returns([/banana$/, /[^\A]BananaLib/])

              Xcodeproj::XCScheme.expects(:share_scheme).never
              @generator.configure_schemes(pod_generator_result.project, @generator.pod_targets, pod_generator_result)
            end

            it 'raises when an invalid type is set' do
              @generator.installation_options.
                  stubs(:share_schemes_for_development_pods).
                  returns(Pathname('foo'))

              pod_generator_result = @generator.generate!
              @generator.sandbox.stubs(:development_pods).returns('BananaLib' => fixture('BananaLib'), 'PineappleLib' => fixture_spec('pineapple-lib/PineappleLib.podspec'))
              Xcodeproj::XCScheme.expects(:share_scheme).never
              e = should.raise(Informative) { @generator.configure_schemes(pod_generator_result.project, @generator.pod_targets, pod_generator_result) }
              e.message.should.match /share_schemes_for_development_pods.*set it to true, false, or an array of pods to share schemes for/
            end
          end
        end
      end
    end
  end
end
