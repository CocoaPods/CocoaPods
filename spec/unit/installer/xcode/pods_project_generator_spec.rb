require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  class Installer
    class Xcode
      describe PodsProjectGenerator do
        describe 'Generating Pods Project' do
          before do
            @ios_platform = Platform.new(:ios, '6.0')
            @osx_platform = Platform.new(:osx, '10.8')

            @ios_target_definition = fixture_target_definition('SampleApp-iOS', @ios_platform)
            @osx_target_definition = fixture_target_definition('SampleApp-macOS', @osx_platform)

            user_build_configurations = { 'Debug' => :debug, 'Release' => :release, 'App Store' => :release, 'Test' => :debug }

            @monkey_spec = fixture_spec('monkey/monkey.podspec')
            @monkey_ios_pod_target = fixture_pod_target(@monkey_spec, false,
                                                        user_build_configurations, [], @ios_platform,
                                                        [@ios_target_definition], 'iOS')
            @monkey_osx_pod_target = fixture_pod_target(@monkey_spec, false,
                                                        user_build_configurations, [], @osx_platform,
                                                        [@osx_target_definition], 'macOS')

            @banana_spec = fixture_spec('banana-lib/BananaLib.podspec')
            @banana_ios_pod_target = fixture_pod_target(@banana_spec, false,
                                                        user_build_configurations, [], @ios_platform,
                                                        [@ios_target_definition], 'iOS')
            @banana_osx_pod_target = fixture_pod_target(@banana_spec, false,
                                                        user_build_configurations, [], @osx_platform,
                                                        [@osx_target_definition], 'macOS')

            @orangeframework_spec = fixture_spec('orange-framework/OrangeFramework.podspec')
            @orangeframework_pod_target = fixture_pod_target_with_specs([@orangeframework_spec], false,
                                                                        user_build_configurations, [], @ios_platform,
                                                                        [@ios_target_definition])
            @coconut_spec = fixture_spec('coconut-lib/CoconutLib.podspec')
            @coconut_test_spec = @coconut_spec.test_specs.first
            @coconut_ios_pod_target = fixture_pod_target_with_specs([@coconut_spec, @coconut_test_spec],
                                                                    false,
                                                                    user_build_configurations, [], @ios_platform,
                                                                    [@ios_target_definition],
                                                                    'iOS')
            @coconut_ios_pod_target.dependent_targets = [@orangeframework_pod_target]

            @coconut_osx_pod_target = fixture_pod_target_with_specs([@coconut_spec, @coconut_test_spec],
                                                                    false,
                                                                    user_build_configurations, [], @osx_platform,
                                                                    [@osx_target_definition],
                                                                    'macOS')

            ios_pod_targets = [@banana_ios_pod_target, @monkey_ios_pod_target, @coconut_ios_pod_target,
                               @orangeframework_pod_target]
            osx_pod_targets = [@banana_osx_pod_target, @monkey_osx_pod_target, @coconut_osx_pod_target]
            pod_targets = ios_pod_targets + osx_pod_targets

            @ios_target = fixture_aggregate_target(ios_pod_targets, false,
                                                   user_build_configurations, [], @ios_platform,
                                                   @ios_target_definition)
            @osx_target = fixture_aggregate_target(osx_pod_targets, false,
                                                   user_build_configurations, [], @osx_platform,
                                                   @osx_target_definition)

            aggregate_targets = [@ios_target, @osx_target]

            @analysis_result = Pod::Installer::Analyzer::AnalysisResult.new(Pod::Installer::Analyzer::SpecsState.new,
                                                                            {}, {}, [],
                                                                            Pod::Installer::Analyzer::SpecsState.new,
                                                                            aggregate_targets, pod_targets, nil)

            @installation_options = Pod::Installer::InstallationOptions.new

            @generator = PodsProjectGenerator.new(config.sandbox, aggregate_targets, pod_targets, @analysis_result,
                                                  @installation_options, config)
          end

          it "creates build configurations for all of the user's targets" do
            @generator.generate!
            @generator.project.build_configurations.map(&:name).sort.should == ['App Store', 'Debug', 'Release', 'Test']
          end

          it 'sets STRIP_INSTALLED_PRODUCT to NO for all configurations for the whole project' do
            @generator.generate!
            @generator.project.build_settings('Debug')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
            @generator.project.build_settings('Test')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
            @generator.project.build_settings('Release')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
            @generator.project.build_settings('App Store')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
          end

          it 'sets the SYMROOT to the default value for all configurations for the whole project' do
            @generator.generate!
            @generator.project.build_settings('Debug')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
            @generator.project.build_settings('Test')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
            @generator.project.build_settings('Release')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
            @generator.project.build_settings('App Store')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
          end

          it 'creates the correct Pods project' do
            @generator.generate!
            @generator.project.class.should == Pod::Project
          end

          it 'adds the Podfile to the Pods project' do
            config.stubs(:podfile_path).returns(Pathname.new('/Podfile'))
            @generator.generate!
            @generator.project['Podfile'].should.be.not.nil
          end

          it 'sets the deployment target for the whole project' do
            @generator.generate!
            build_settings = @generator.project.build_configurations.map(&:build_settings)
            build_settings.each do |build_setting|
              build_setting['MACOSX_DEPLOYMENT_TARGET'].should == '10.8'
              build_setting['IPHONEOS_DEPLOYMENT_TARGET'].should == '6.0'
            end
          end

          it 'installs file references' do
            @generator.generate!
            banana_group = @generator.project.group_for_spec('BananaLib')
            banana_group.files.map(&:name).sort.should == [
              'Banana.h',
              'Banana.m',
              'BananaPrivate.h',
              'BananaTrace.d',
              'MoreBanana.h',
            ]
            monkey_group = @generator.project.group_for_spec('monkey')
            monkey_group.files.map(&:name).sort.should.be.empty # pre-built pod
            organge_framework_group = @generator.project.group_for_spec('OrangeFramework')
            organge_framework_group.files.map(&:name).sort.should. == [
              'Juicer.swift',
            ]
            coconut_group = @generator.project.group_for_spec('CoconutLib')
            coconut_group.files.map(&:name).sort.should == [
              'Coconut.h',
              'Coconut.m',
            ]
          end

          it 'installs the correct targets in the project' do
            @generator.generate!
            @generator.project.targets.map(&:name).sort.should == [
              'BananaLib-iOS',
              'BananaLib-macOS',
              'CoconutLib-iOS',
              'CoconutLib-iOS-Unit-Tests',
              'CoconutLib-macOS',
              'CoconutLib-macOS-Unit-Tests',
              'OrangeFramework',
              'Pods-SampleApp-iOS',
              'Pods-SampleApp-macOS',
              'monkey-iOS',
              'monkey-macOS',
            ]
          end

          it 'sets the pod and aggregate target dependencies' do
            @generator.generate!
            @generator.project.targets.find { |t| t.name == 'BananaLib-iOS' }.dependencies.map(&:name).should.be.empty
            @generator.project.targets.find { |t| t.name == 'BananaLib-macOS' }.dependencies.map(&:name).should.be.empty
            @generator.project.targets.find { |t| t.name == 'CoconutLib-macOS' }.dependencies.map(&:name).should.be.empty
            @generator.project.targets.find { |t| t.name == 'monkey-iOS' }.dependencies.map(&:name).should.be.empty
            @generator.project.targets.find { |t| t.name == 'monkey-macOS' }.dependencies.map(&:name).should.be.empty
            @generator.project.targets.find { |t| t.name == 'CoconutLib-iOS' }.dependencies.map(&:name).sort.should == [
              'OrangeFramework',
            ]
            @generator.project.targets.find { |t| t.name == 'Pods-SampleApp-iOS' }.dependencies.map(&:name).sort.should == [
              'BananaLib-iOS',
              'CoconutLib-iOS',
              'OrangeFramework',
              'monkey-iOS',
            ]
            @generator.project.targets.find { |t| t.name == 'Pods-SampleApp-macOS' }.dependencies.map(&:name).sort.should == [
              'BananaLib-macOS',
              'CoconutLib-macOS',
              'monkey-macOS',
            ]
          end

          it 'adds no system frameworks to static targets' do
            @generator.generate!
            @generator.project.targets.find { |t| t.name == 'OrangeFramework' }.frameworks_build_phase.file_display_names.should == []
          end

          it 'adds system frameworks to dynamic targets' do
            @orangeframework_pod_target.stubs(:requires_frameworks? => true)
            @generator.generate!
            @generator.project.targets.find { |t| t.name == 'OrangeFramework' }.frameworks_build_phase.file_display_names.should == %w(
              Foundation.framework
              UIKit.framework
            )
          end

          it 'adds target dependencies when inheriting search paths' do
            inherited_target_definition = fixture_target_definition('SampleApp-iOS-Tests', @ios_platform)
            inherited_target = fixture_aggregate_target([], false,
                                                        @ios_target.user_build_configurations, [],
                                                        @ios_target.platform, inherited_target_definition)
            inherited_target.search_paths_aggregate_targets << @ios_target
            @generator.aggregate_targets << inherited_target
            @generator.generate!
            @generator.project.targets.find { |t| t.name == 'Pods-SampleApp-iOS-Tests' }.dependencies.map(&:name).sort.should == [
              'Pods-SampleApp-iOS',
            ]
          end

          it 'sets resource bundle target dependencies' do
            @banana_spec.resource_bundles = { 'BananaLibResourcesBundle' => '**/*' }
            @generator.generate!
            @generator.project.targets.find { |t| t.name == 'BananaLib-iOS-BananaLibResourcesBundle' }.should.not.be.nil
            @generator.project.targets.find { |t| t.name == 'BananaLib-macOS-BananaLibResourcesBundle' }.should.not.be.nil
            @generator.project.targets.find { |t| t.name == 'BananaLib-iOS' }.dependencies.map(&:name).should == [
              'BananaLib-iOS-BananaLibResourcesBundle',
            ]
            @generator.project.targets.find { |t| t.name == 'BananaLib-macOS' }.dependencies.map(&:name).should == [
              'BananaLib-macOS-BananaLibResourcesBundle',
            ]
          end

          it 'sets test resource bundle dependencies' do
            @coconut_test_spec.resource_bundles = { 'CoconutLibTestResourcesBundle' => '**/*' }
            @generator.generate!
            @generator.project.targets.find { |t| t.name == 'CoconutLib-iOS-CoconutLibTestResourcesBundle' }.should.not.be.nil
            @generator.project.targets.find { |t| t.name == 'CoconutLib-macOS-CoconutLibTestResourcesBundle' }.should.not.be.nil
            @generator.project.targets.find { |t| t.name == 'CoconutLib-iOS-Unit-Tests' }.dependencies.map(&:name).sort.should == [
              'CoconutLib-iOS',
              'CoconutLib-iOS-CoconutLibTestResourcesBundle',
              'OrangeFramework',
            ]
            @generator.project.targets.find { |t| t.name == 'CoconutLib-macOS-Unit-Tests' }.dependencies.map(&:name).sort.should == [
              'CoconutLib-macOS',
              'CoconutLib-macOS-CoconutLibTestResourcesBundle',
            ]
          end

          it 'sets the app host dependency for the tests that need it' do
            @coconut_test_spec.ios.requires_app_host = true
            @generator.generate!
            @generator.project.targets.find { |t| t.name == 'AppHost-iOS-Unit-Tests' }.should.not.be.nil
            @generator.project.targets.find { |t| t.name == 'CoconutLib-iOS-Unit-Tests' }.dependencies.map(&:name).sort.should == [
              'AppHost-iOS-Unit-Tests',
              'CoconutLib-iOS',
              'OrangeFramework',
            ]
            @generator.project.targets.find { |t| t.name == 'CoconutLib-macOS-Unit-Tests' }.dependencies.map(&:name).should == [
              'CoconutLib-macOS',
            ]
          end

          it 'adds framework file references for framework pod targets that require building' do
            @orangeframework_pod_target.stubs(:requires_frameworks?).returns(true)
            @coconut_ios_pod_target.stubs(:requires_frameworks?).returns(true)
            @coconut_ios_pod_target.stubs(:should_build?).returns(true)
            @generator.generate!
            native_target = @generator.project.targets.find { |t| t.name == 'CoconutLib-iOS' }
            native_target.isa.should == 'PBXNativeTarget'
            native_target.frameworks_build_phase.file_display_names.sort.should == [
              'Foundation.framework',
              'OrangeFramework.framework',
            ]
          end

          it 'does not add framework references for framework pod targets that do not require building' do
            @orangeframework_pod_target.stubs(:requires_frameworks?).returns(true)
            @coconut_ios_pod_target.stubs(:requires_frameworks?).returns(true)
            @coconut_ios_pod_target.stubs(:should_build?).returns(false)
            @generator.generate!
            @generator.project.targets.find { |t| t.name == 'CoconutLib-iOS' }.isa.should == 'PBXAggregateTarget'
          end

          it 'configures APPLICATION_EXTENSION_API_ONLY for pod targets of an aggregate target' do
            user_target = stub('SampleApp-iOS-User-Target', :symbol_type => :app_extension)
            @ios_target.stubs(:user_targets).returns([user_target])
            @generator.generate!
            @generator.project.targets.find { |t| t.name == 'Pods-SampleApp-iOS' }.dependencies.each do |dependency|
              build_settings = @generator.project.targets.find { |t| t.name == dependency.name }.build_configurations.map(&:build_settings)
              build_settings.each do |build_setting|
                build_setting['APPLICATION_EXTENSION_API_ONLY'].should == 'YES'
              end
            end
          end

          it 'configures APPLICATION_EXTENSION_API_ONLY for app extension targets' do
            user_target = stub('SampleApp-iOS-User-Target', :symbol_type => :app_extension)
            @ios_target.stubs(:user_targets).returns([user_target])
            @generator.generate!
            build_settings = @generator.project.targets.find { |t| t.name == 'Pods-SampleApp-iOS' }.build_configurations.map(&:build_settings)
            build_settings.each do |build_setting|
              build_setting['APPLICATION_EXTENSION_API_ONLY'].should == 'YES'
            end
          end

          it 'configures APPLICATION_EXTENSION_API_ONLY for watch2 extension targets' do
            user_target = stub('SampleApp-iOS-User-Target', :symbol_type => :watch2_extension)
            @ios_target.stubs(:user_targets).returns([user_target])
            @generator.generate!
            build_settings = @generator.project.targets.find { |t| t.name == 'Pods-SampleApp-iOS' }.build_configurations.map(&:build_settings)
            build_settings.each do |build_setting|
              build_setting['APPLICATION_EXTENSION_API_ONLY'].should == 'YES'
            end
          end

          it 'configures APPLICATION_EXTENSION_API_ONLY for tvOS extension targets' do
            user_target = stub('SampleApp-iOS-User-Target', :symbol_type => :tv_extension)
            @ios_target.stubs(:user_targets).returns([user_target])
            @generator.generate!
            build_settings = @generator.project.targets.find { |t| t.name == 'Pods-SampleApp-iOS' }.build_configurations.map(&:build_settings)
            build_settings.each do |build_setting|
              build_setting['APPLICATION_EXTENSION_API_ONLY'].should == 'YES'
            end
          end

          it 'configures APPLICATION_EXTENSION_API_ONLY for Messages extension targets' do
            user_target = stub('SampleApp-iOS-User-Target', :symbol_type => :messages_extension)
            @ios_target.stubs(:user_targets).returns([user_target])
            @generator.generate!
            build_settings = @generator.project.targets.find { |t| t.name == 'Pods-SampleApp-iOS' }.build_configurations.map(&:build_settings)
            build_settings.each do |build_setting|
              build_setting['APPLICATION_EXTENSION_API_ONLY'].should == 'YES'
            end
          end

          it "uses the user project's object version for the pods project" do
            tmp_directory = Pathname(Dir.tmpdir) + 'CocoaPods'
            FileUtils.mkdir_p(tmp_directory)
            proj = Xcodeproj::Project.new(tmp_directory + 'Yolo.xcodeproj', false, 1)
            proj.save

            user_target = stub('SampleApp-iOS-User-Target', :symbol_type => :application)
            user_target.expects(:common_resolved_build_setting).with('APPLICATION_EXTENSION_API_ONLY').returns('NO')

            target = AggregateTarget.new(config.sandbox, false,
                                         { 'App Store' => :release, 'Debug' => :debug, 'Release' => :release, 'Test' => :debug },
                                         [], Platform.new(:ios, '6.0'), fixture_target_definition,
                                         config.sandbox.root.dirname, proj, nil, {})

            target.stubs(:user_targets).returns([user_target])

            @generator = PodsProjectGenerator.new(config.sandbox, [target], [],
                                                  @analysis_result, @installation_options, config)
            @generator.generate!
            @generator.project.object_version.should == '1'

            FileUtils.rm_rf(tmp_directory)
          end

          describe '#write' do
            it 'recursively sorts the project' do
              @generator.generate!
              @generator.project.main_group.expects(:sort)
              Xcodeproj::Project.any_instance.stubs(:recreate_user_schemes)
              @generator.write
            end

            it 'saves the project to the given path' do
              @generator.generate!
              Xcodeproj::Project.any_instance.stubs(:recreate_user_schemes)
              temporary_directory + 'Pods/Pods.xcodeproj'
              @generator.project.expects(:save)
              @generator.write
            end
          end

          describe '#share_development_pod_schemes' do
            it 'does not share by default' do
              Xcodeproj::XCScheme.expects(:share_scheme).never
              @generator.share_development_pod_schemes
            end

            it 'can share all schemes' do
              @generator.installation_options.
                  stubs(:share_schemes_for_development_pods).
                  returns(true)

              @generator.generate!
              @generator.sandbox.stubs(:development_pods).returns('BananaLib' => fixture('BananaLib'))

              Xcodeproj::XCScheme.expects(:share_scheme).with(
                @generator.project.path,
                'BananaLib-iOS')

              Xcodeproj::XCScheme.expects(:share_scheme).with(
                @generator.project.path,
                'BananaLib-macOS')

              @generator.share_development_pod_schemes
            end
          end

          it 'shares test schemes' do
            @generator.installation_options.
                stubs(:share_schemes_for_development_pods).
                returns(true)
            @generator.sandbox.stubs(:development_pods).returns('CoconutLib' => fixture('CoconutLib'))

            @generator.generate!

            Xcodeproj::XCScheme.expects(:share_scheme).with(
              @generator.project.path,
              'CoconutLib-iOS')

            Xcodeproj::XCScheme.expects(:share_scheme).with(
              @generator.project.path,
              'CoconutLib-iOS-Unit-Tests')

            Xcodeproj::XCScheme.expects(:share_scheme).with(
              @generator.project.path,
              'CoconutLib-macOS')

            Xcodeproj::XCScheme.expects(:share_scheme).with(
              @generator.project.path,
              'CoconutLib-macOS-Unit-Tests')

            @generator.share_development_pod_schemes
          end

          it 'allows opting out' do
            @generator.installation_options.
                stubs(:share_schemes_for_development_pods).
                returns(false)

            Xcodeproj::XCScheme.expects(:share_scheme).never
            @generator.share_development_pod_schemes

            @generator.installation_options.
                stubs(:share_schemes_for_development_pods).
                returns(nil)

            Xcodeproj::XCScheme.expects(:share_scheme).never
            @generator.share_development_pod_schemes
          end

          it 'allows specifying strings of pods to share' do
            @generator.installation_options.
                stubs(:share_schemes_for_development_pods).
                returns(%w(BananaLib))

            @generator.generate!
            @generator.sandbox.stubs(:development_pods).returns('BananaLib' => fixture('BananaLib'))

            Xcodeproj::XCScheme.expects(:share_scheme).with(
              @generator.project.path,
              'BananaLib-iOS')

            Xcodeproj::XCScheme.expects(:share_scheme).with(
              @generator.project.path,
              'BananaLib-macOS')

            @generator.share_development_pod_schemes

            @generator.installation_options.
                stubs(:share_schemes_for_development_pods).
                returns(%w(orange-framework))

            Xcodeproj::XCScheme.expects(:share_scheme).never
            @generator.share_development_pod_schemes
          end

          it 'allows specifying regular expressions of pods to share' do
            @generator.installation_options.
                stubs(:share_schemes_for_development_pods).
                returns([/bAnaNalIb/i, /B*/])

            @generator.generate!
            @generator.sandbox.stubs(:development_pods).returns('BananaLib' => fixture('BananaLib'))

            Xcodeproj::XCScheme.expects(:share_scheme).with(
              @generator.project.path,
              'BananaLib-iOS')

            Xcodeproj::XCScheme.expects(:share_scheme).with(
              @generator.project.path,
              'BananaLib-macOS')

            @generator.share_development_pod_schemes

            @generator.installation_options.
                stubs(:share_schemes_for_development_pods).
                returns([/banana$/, /[^\A]BananaLib/])

            Xcodeproj::XCScheme.expects(:share_scheme).never
            @generator.share_development_pod_schemes
          end

          it 'raises when an invalid type is set' do
            @generator.installation_options.
                stubs(:share_schemes_for_development_pods).
                returns(Pathname('foo'))

            @generator.generate!
            @generator.sandbox.stubs(:development_pods).returns('BananaLib' => fixture('BananaLib'))

            Xcodeproj::XCScheme.expects(:share_scheme).never
            e = should.raise(Informative) { @generator.share_development_pod_schemes }
            e.message.should.match /share_schemes_for_development_pods.*set it to true, false, or an array of pods to share schemes for/
          end
        end
      end
    end
  end
end
