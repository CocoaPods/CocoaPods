require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe TargetInspector = Installer::Analyzer::TargetInspector do
    before do
      SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
    end

    describe '#compute_results' do
      it 'checks the path' do
        target_definition = Podfile::TargetDefinition.new('UserTarget', nil)
        user_project = Xcodeproj::Project.new('UserProject.xcodeproj')
        user_project.new_target(:application, 'UserTarget', :ios)
        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        results = target_inspector.send(:compute_results, user_project)
        results.client_root.to_s.should == Dir.getwd.to_s
      end

      it 'checks the adjusted path' do
        target_definition = Podfile::TargetDefinition.new('UserTarget', nil)
        user_project = Xcodeproj::Project.new('UserProject.xcodeproj')
        user_project.new_target(:application, 'UserTarget', :ios)
        user_project.root_object.stubs(:project_dir_path).returns('../')
        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        results = target_inspector.send(:compute_results, user_project)
        results.client_root.to_s.should.not.include Dir.getwd.to_s
        Dir.getwd.to_s.should.include results.client_root.to_s
      end
    end

    describe '#compute_project_path' do
      it 'uses the path specified in the target definition while computing the path of the user project' do
        target_definition = Podfile::TargetDefinition.new(:default, nil)
        target_definition.user_project_path = 'SampleProject/SampleProject'

        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        path = target_inspector.compute_project_path
        path.to_s.should.include 'SampleProject/SampleProject.xcodeproj'
      end

      it 'raises if the user project of the target definition does not exists while computing the path of the user project' do
        target_definition = Podfile::TargetDefinition.new(:default, nil)
        target_definition.user_project_path = 'Test'

        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        e = lambda { target_inspector.compute_project_path }.should.raise Informative
        e.message.should.match /Unable to find/
      end

      it 'looks if there is only one project if not specified in the target definition' do
        target_definition = Podfile::TargetDefinition.new(:default, nil)
        config.installation_root = config.installation_root + 'SampleProject'

        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        path = target_inspector.compute_project_path
        path.to_s.should.include 'SampleProject/SampleProject.xcodeproj'
      end

      it 'raise if there is no project and none specified in the target definition' do
        target_definition = Podfile::TargetDefinition.new(:default, nil)

        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        e = lambda { target_inspector.compute_project_path }.should.raise Informative
        e.message.should.match /Could not.*select.*project/
      end

      it 'finds project even when path contains special chars' do
        SpecHelper.create_sample_app_copy_from_fixture('Project[With]Special{chars}in*path?')

        target_definition = Podfile::TargetDefinition.new(:default, nil)
        config.installation_root = config.installation_root + 'Project[With]Special{chars}in*path?'

        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        path = target_inspector.compute_project_path
        path.to_s.should.include 'Project[With]Special{chars}in*path?/Project[With]Special{chars}in*path?.xcodeproj'
      end
    end

    #--------------------------------------#

    describe '#compute_targets' do
      it 'returns the targets specified in the target definition' do
        target_definition = Podfile::TargetDefinition.new('UserTarget', nil)
        user_project = Xcodeproj::Project.new('UserProject.xcodeproj')
        user_project.new_target(:application, 'FirstTarget', :ios)
        user_project.new_target(:application, 'UserTarget', :ios)

        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        targets = target_inspector.send(:compute_targets, user_project)
        targets.map(&:name).should == ['UserTarget']
      end

      it 'raises if it is unable to find the targets specified by the target definition' do
        target_definition = Podfile::TargetDefinition.new('UserTarget', nil)
        user_project = Xcodeproj::Project.new('UserProject.xcodeproj')

        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        e = lambda { target_inspector.send(:compute_targets, user_project) }.should.raise Informative
        e.message.should.match /Unable to find a target named `UserTarget` in project `UserProject.xcodeproj`/
      end

      it 'suggests project native target names if the target cannot be found' do
        target_definition = Podfile::TargetDefinition.new('UserTarget', nil)
        user_project = Xcodeproj::Project.new('path')
        user_project.new_target(:application, 'FirstTarget', :ios)
        user_project.new_target(:application, 'SecondTarget', :ios)
        user_project.new_target(:application, 'ThirdTarget', :ios)

        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        e = lambda { target_inspector.send(:compute_targets, user_project) }.should.raise Informative
        e.message.should.include 'did find `FirstTarget`, `SecondTarget`, and `ThirdTarget`.'
      end

      it 'returns the target with the same name of the target definition' do
        target_definition = Podfile::TargetDefinition.new('UserTarget', nil)
        user_project = Xcodeproj::Project.new('path')
        user_project.new_target(:application, 'FirstTarget', :ios)
        user_project.new_target(:application, 'UserTarget', :ios)

        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        targets = target_inspector.send(:compute_targets, user_project)
        targets.map(&:name).should == ['UserTarget']
      end

      it 'raises if the name of the target definition does not match any file' do
        target_definition = Podfile::TargetDefinition.new('UserTarget', nil)
        user_project = Xcodeproj::Project.new('path')

        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        e = lambda { target_inspector.send(:compute_targets, user_project) }.should.raise Informative
        e.message.should.match /Unable to find a target named/
      end
    end

    #--------------------------------------#

    describe '#compute_build_configurations' do
      it 'returns the user build configurations of the user targets' do
        user_project = Xcodeproj::Project.new('path')
        target = user_project.new_target(:application, 'Target', :ios)
        configuration = user_project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
        configuration.name = 'AppStore'
        target.build_configuration_list.build_configurations << configuration

        target_definition = Podfile::TargetDefinition.new(:default, nil)
        user_targets = [target]

        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        configurations = target_inspector.send(:compute_build_configurations, user_targets)
        configurations.should == {
          'Debug'    => :debug,
          'Release'  => :release,
          'AppStore' => :release,
        }
      end

      it 'returns the user build configurations specified in the target definition' do
        target_definition = Podfile::TargetDefinition.new(:default, nil)
        target_definition.build_configurations = { 'AppStore' => :release }
        user_targets = []

        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        configurations = target_inspector.send(:compute_build_configurations, user_targets)
        configurations.should == { 'AppStore' => :release }
      end
    end

    #--------------------------------------#

    describe '#compute_archs' do
      it 'handles a single ARCH defined in a single user target' do
        user_project = Xcodeproj::Project.new('path')
        target = user_project.new_target(:application, 'Target', :ios)
        target.build_configuration_list.set_setting('ARCHS', 'armv7')

        target_definition = Podfile::TargetDefinition.new(:default, nil)
        target_definition.set_platform(:ios, '4.0')
        user_targets = [target]

        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        archs = target_inspector.send(:compute_archs, user_targets)
        archs.should == %w(armv7)
      end

      it 'handles a single ARCH defined in multiple user targets' do
        user_project = Xcodeproj::Project.new('path')
        targeta = user_project.new_target(:application, 'Target', :ios)
        targeta.build_configuration_list.set_setting('ARCHS', 'armv7')
        targetb = user_project.new_target(:application, 'Target', :ios)
        targetb.build_configuration_list.set_setting('ARCHS', 'armv7')

        target_definition = Podfile::TargetDefinition.new(:default, nil)
        target_definition.set_platform(:ios, '4.0')
        user_targets = [targeta, targetb]

        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        archs = target_inspector.send(:compute_archs, user_targets)
        archs.should == %w(armv7)
      end

      it 'handles an Array of ARCHs defined in a single user target' do
        user_project = Xcodeproj::Project.new('path')
        target = user_project.new_target(:application, 'Target', :ios)
        target.build_configuration_list.set_setting('ARCHS', %w(armv7 i386))

        target_definition = Podfile::TargetDefinition.new(:default, nil)
        target_definition.set_platform(:ios, '4.0')
        user_targets = [target]

        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        archs = target_inspector.send(:compute_archs, user_targets)
        archs.uniq.sort.should == %w(armv7 i386)
      end

      it 'handles an Array of ARCHs defined multiple user targets' do
        user_project = Xcodeproj::Project.new('path')
        target_a = user_project.new_target(:application, 'Target', :ios)
        target_a.build_configuration_list.set_setting('ARCHS', %w(armv7 armv7s))
        target_b = user_project.new_target(:application, 'Target', :ios)
        target_b.build_configuration_list.set_setting('ARCHS', %w(armv7 i386))

        target_definition = Podfile::TargetDefinition.new(:default, nil)
        target_definition.set_platform(:ios, '4.0')
        user_targets = [target_a, target_b]

        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        archs = target_inspector.send(:compute_archs, user_targets)
        archs.uniq.sort.should == %w(armv7 armv7s i386)
      end
    end

    #--------------------------------------#

    describe '#compute_platform' do
      it 'returns the platform specified in the target definition' do
        target_definition = Podfile::TargetDefinition.new(:default, nil)
        target_definition.set_platform(:ios, '4.0')
        user_targets = []

        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        platforms = target_inspector.send(:compute_platform, user_targets)
        platforms.should == Platform.new(:ios, '4.0')
      end

      it 'infers the platform from the user targets' do
        user_project = Xcodeproj::Project.new('path')
        target = user_project.new_target(:application, 'Target', :ios)
        target.build_configuration_list.set_setting('SDKROOT', 'iphoneos')
        target.build_configuration_list.set_setting('IPHONEOS_DEPLOYMENT_TARGET', '4.0')

        target_definition = Podfile::TargetDefinition.new(:default, nil)
        user_targets = [target]

        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        platforms = target_inspector.send(:compute_platform, user_targets)
        platforms.should == Platform.new(:ios, '4.0')
        UI.warnings.should.include 'Automatically assigning platform `iOS` with version `4.0` on target `default` because no ' \
          'platform was specified. Please specify a platform for this target in your Podfile. ' \
          'See `https://guides.cocoapods.org/syntax/podfile.html#platform`.'
      end

      it 'uses the lowest deployment target of the user targets if inferring the platform' do
        user_project = Xcodeproj::Project.new('path')
        target1 = user_project.new_target(:application, 'Target', :ios)
        target1.build_configuration_list.build_configurations.first
        target1.build_configuration_list.set_setting('SDKROOT', 'iphoneos')
        target1.build_configuration_list.set_setting('IPHONEOS_DEPLOYMENT_TARGET', '4.0')

        target2 = user_project.new_target(:application, 'Target', :ios)
        target2.build_configuration_list.set_setting('SDKROOT', 'iphoneos')
        target2.build_configuration_list.set_setting('IPHONEOS_DEPLOYMENT_TARGET', '6.0')

        target_definition = Podfile::TargetDefinition.new(:default, nil)
        user_targets = [target1, target2]

        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        platforms = target_inspector.send(:compute_platform, user_targets)
        platforms.should == Platform.new(:ios, '4.0')
      end

      it 'raises if the user targets have a different platform' do
        user_project = Xcodeproj::Project.new('path')
        target1 = user_project.new_target(:application, 'Target', :ios)
        target1.build_configuration_list.set_setting('SDKROOT', 'iphoneos')
        target1.build_configuration_list.set_setting('IPHONEOS_DEPLOYMENT_TARGET', '4.0')

        target2 = user_project.new_target(:application, 'Target', :ios)
        target2.build_configuration_list.set_setting('SDKROOT', 'macosx')
        target2.build_configuration_list.set_setting('IPHONEOS_DEPLOYMENT_TARGET', '10.6')

        target_definition = Podfile::TargetDefinition.new(:default, nil)
        user_targets = [target1, target2]

        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        e = lambda { target_inspector.send(:compute_platform, user_targets) }.should.raise Informative
        e.message.should.match /Targets with different platforms/
      end

      it 'raises if the platform cannot be inferred' do
        user_project = Xcodeproj::Project.new('path')
        target = user_project.new_target(:application, 'Target', :ios)
        target.build_configuration_list.set_setting('SDKROOT', nil)

        target_definition = Podfile::TargetDefinition.new(:default, nil)
        user_targets = [target]

        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        should.raise(Informative) { target_inspector.send(:compute_platform, user_targets) }.
          message.should.include('Unable to determine the platform for the `default` target.')
      end
    end

    #--------------------------------------#

    describe '#compute_swift_version_from_targets' do
      it 'returns the user defined SWIFT_VERSION if only one unique version is defined' do
        user_project = Xcodeproj::Project.new('path')
        target = user_project.new_target(:application, 'Target', :ios)
        target.build_configuration_list.set_setting('SWIFT_VERSION', '2.3')

        target_definition = Podfile::TargetDefinition.new(:default, nil)
        user_targets = [target]

        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        target_inspector.send(:compute_swift_version_from_targets, user_targets).should.equal '2.3'
      end

      it 'returns default if the version is not defined' do
        user_project = Xcodeproj::Project.new('path')
        user_project.build_configuration_list.set_setting('SWIFT_VERSION', nil)
        target = user_project.new_target(:application, 'Target', :ios)
        target.build_configuration_list.set_setting('SWIFT_VERSION', nil)

        target_definition = Podfile::TargetDefinition.new(:default, nil)
        user_targets = [target]

        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        target_inspector.send(:compute_swift_version_from_targets, user_targets).should.nil?
      end

      it 'raises if the user defined SWIFT_VERSION contains multiple unique versions are defined' do
        user_project = Xcodeproj::Project.new('path')
        target = user_project.new_target(:application, 'Target', :ios)
        target.build_configuration_list.build_configurations.first.build_settings['SWIFT_VERSION'] = '2.3'
        target.build_configuration_list.build_configurations.last.build_settings['SWIFT_VERSION'] = '3.0'

        target_definition = Podfile::TargetDefinition.new(:default, nil)
        user_targets = [target]

        target_inspector = TargetInspector.new(target_definition, config.installation_root)

        expected_versions_string = "Target: Swift 2.3\nTarget: Swift 3.0"

        should.raise(Informative) do
          target_inspector.send(:compute_swift_version_from_targets, user_targets)
        end.message.should.include "There may only be up to 1 unique SWIFT_VERSION per target. Found target(s) with multiple Swift versions:\n#{expected_versions_string}"
      end

      it 'raises if the user defined SWIFT_VERSION contains multiple unique versions are defined on different targets' do
        user_project = Xcodeproj::Project.new('path')
        target = user_project.new_target(:application, 'Target', :ios)
        target.build_configuration_list.set_setting('SWIFT_VERSION', '2.3')

        target2 = user_project.new_target(:application, 'Target2', :ios)
        target2.build_configuration_list.set_setting('SWIFT_VERSION', '3.0')

        target_definition = Podfile::TargetDefinition.new(:default, nil)
        user_targets = [target, target2]

        target_inspector = TargetInspector.new(target_definition, config.installation_root)

        expected_versions_string = "Target: Swift 2.3\nTarget2: Swift 3.0"

        should.raise(Informative) do
          target_inspector.send(:compute_swift_version_from_targets, user_targets)
        end.message.should.include "There may only be up to 1 unique SWIFT_VERSION per target. Found target(s) with multiple Swift versions:\n#{expected_versions_string}"
      end

      it 'returns the project-level SWIFT_VERSION if the target-level SWIFT_VERSION is not defined' do
        user_project = Xcodeproj::Project.new('path')
        user_project.build_configuration_list.set_setting('SWIFT_VERSION', '2.3')
        target = user_project.new_target(:application, 'Target', :ios)
        target_definition = Podfile::TargetDefinition.new(:default, nil)
        user_targets = [target]

        target_inspector = TargetInspector.new(target_definition, config.installation_root)
        target_inspector.send(:compute_swift_version_from_targets, user_targets).should.equal '2.3'
      end

      describe 'with user xcconfig set' do
        before do
          @user_xcconfig = 'User.xcconfig'
        end

        after do
          FileUtils.rm_f(@user_xcconfig) if File.exist?(@user_xcconfig)
        end

        it 'verify path adjustments are made to config path' do
          user_project = Xcodeproj::Project.new('path')
          sample_config = user_project.new_file(@user_xcconfig)
          user_project.root_object.stubs(:project_dir_path).returns('foo')
          sample_config.real_path.to_s.should.include 'foo/User.xcconfig'
        end

        it 'returns the xcconfig-level SWIFT_VERSION if the target has an existing user xcconfig set' do
          user_project = Xcodeproj::Project.new('path')
          user_project.build_configuration_list.set_setting('SWIFT_VERSION', '2.3')
          target = user_project.new_target(:application, 'Target', :ios)
          sample_config = user_project.new_file(@user_xcconfig)
          File.write(sample_config.real_path, 'SWIFT_VERSION=3.0')
          target.build_configurations.each do |config|
            config.base_configuration_reference = sample_config
          end

          target_definition = Podfile::TargetDefinition.new(:default, nil)
          user_targets = [target]

          target_inspector = TargetInspector.new(target_definition, config.installation_root)
          target_inspector.send(:compute_swift_version_from_targets, user_targets).should.equal '3.0'
        end

        it 'returns the xcconfig-level SWIFT_VERSION if the target has an existing user xcconfig set but the file is missing' do
          user_project = Xcodeproj::Project.new('path')
          user_project.build_configuration_list.set_setting('SWIFT_VERSION', '2.3')
          target = user_project.new_target(:application, 'Target', :ios)
          sample_config = user_project.new_file(@user_xcconfig)
          target.build_configurations.each do |config|
            config.base_configuration_reference = sample_config
          end

          target_definition = Podfile::TargetDefinition.new(:default, nil)
          user_targets = [target]

          target_inspector = TargetInspector.new(target_definition, config.installation_root)
          target_inspector.send(:compute_swift_version_from_targets, user_targets).should.equal '2.3'
        end

        it 'returns the xcconfig-level SWIFT_VERSION if the project has an existing user xcconfig set' do
          user_project = Xcodeproj::Project.new('path')
          sample_config = user_project.new_file(@user_xcconfig)
          File.write(sample_config.real_path, 'SWIFT_VERSION=3.0')
          user_project.build_configuration_list.build_configurations.each do |config|
            config.build_settings.delete('SWIFT_VERSION')
            config.base_configuration_reference = sample_config
          end
          target = user_project.new_target(:application, 'Target', :ios)

          target_definition = Podfile::TargetDefinition.new(:default, nil)
          user_targets = [target]

          target_inspector = TargetInspector.new(target_definition, config.installation_root)
          target_inspector.send(:compute_swift_version_from_targets, user_targets).should.equal '3.0'
        end

        it 'skips the xcconfig-level SWIFT_VERSION if the target has an existing user xcconfig set but without it' do
          user_project = Xcodeproj::Project.new('path')
          user_project.build_configuration_list.set_setting('SWIFT_VERSION', '2.3')
          target = user_project.new_target(:application, 'Target', :ios)
          sample_config = user_project.new_file(@user_xcconfig)
          File.write(sample_config.real_path, 'SOMETHING_ELSE=3.0')
          target.build_configurations.each do |config|
            config.base_configuration_reference = sample_config
          end

          target_definition = Podfile::TargetDefinition.new(:default, nil)
          user_targets = [target]

          target_inspector = TargetInspector.new(target_definition, config.installation_root)
          target_inspector.send(:compute_swift_version_from_targets, user_targets).should.equal '2.3'
        end
      end
    end
  end
end
