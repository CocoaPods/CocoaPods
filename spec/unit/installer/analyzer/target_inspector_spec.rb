require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe TargetInspector = Installer::Analyzer::TargetInspector do
    before do
      SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
    end

    describe '#compute_project_path' do
      it 'uses the path specified in the target definition while computing the path of the user project' do
        target_definition = Podfile::TargetDefinition.new(:default, nil)
        target_definition.user_project_path = 'SampleProject/SampleProject'

        path = TargetInspector.new(target_definition).send(:compute_project_path)
        path.to_s.should.include 'SampleProject/SampleProject.xcodeproj'
      end

      it 'raises if the user project of the target definition does not exists while computing the path of the user project' do
        target_definition = Podfile::TargetDefinition.new(:default, nil)
        target_definition.user_project_path = 'Test'

        e = lambda { TargetInspector.new(target_definition).send(:compute_project_path) }.should.raise Informative
        e.message.should.match /Unable to find/
      end

      it 'looks if there is only one project if not specified in the target definition' do
        target_definition = Podfile::TargetDefinition.new(:default, nil)
        config.installation_root = config.installation_root + 'SampleProject'

        path = TargetInspector.new(target_definition).send(:compute_project_path)
        path.to_s.should.include 'SampleProject/SampleProject.xcodeproj'
      end

      it 'raise if there is no project and none specified in the target definition' do
        target_definition = Podfile::TargetDefinition.new(:default, nil)

        e = lambda { TargetInspector.new(target_definition).send(:compute_project_path) }.should.raise Informative
        e.message.should.match /Could not.*select.*project/
      end

      it 'finds project even when path contains special chars' do
        SpecHelper.create_sample_app_copy_from_fixture('Project[With]Special{chars}in*path?')

        target_definition = Podfile::TargetDefinition.new(:default, nil)
        config.installation_root = config.installation_root + 'Project[With]Special{chars}in*path?'

        path = TargetInspector.new(target_definition).send(:compute_project_path)
        path.to_s.should.include 'Project[With]Special{chars}in*path?/Project[With]Special{chars}in*path?.xcodeproj'
      end
    end

    #--------------------------------------#

    describe '#compute_targets' do
      it 'returns the targets specified in the target definition' do
        target_definition = Podfile::TargetDefinition.new(:default, nil)
        target_definition.link_with = ['UserTarget']
        user_project = Xcodeproj::Project.new('path')
        user_project.new_target(:application, 'FirstTarget', :ios)
        user_project.new_target(:application, 'UserTarget', :ios)

        targets = TargetInspector.new(target_definition).send(:compute_targets, user_project)
        targets.map(&:name).should == ['UserTarget']
      end

      it 'raises if it is unable to find the targets specified by the target definition' do
        target_definition = Podfile::TargetDefinition.new(:default, nil)
        target_definition.link_with = ['UserTarget']
        user_project = Xcodeproj::Project.new('path')

        e = lambda { TargetInspector.new(target_definition).send(:compute_targets, user_project) }.should.raise Informative
        e.message.should.match /Unable to find the targets/
      end

      it 'returns the target with the same name of the target definition' do
        target_definition = Podfile::TargetDefinition.new('UserTarget', nil)
        user_project = Xcodeproj::Project.new('path')
        user_project.new_target(:application, 'FirstTarget', :ios)
        user_project.new_target(:application, 'UserTarget', :ios)

        targets = TargetInspector.new(target_definition).send(:compute_targets, user_project)
        targets.map(&:name).should == ['UserTarget']
      end

      it 'raises if the name of the target definition does not match any file' do
        target_definition = Podfile::TargetDefinition.new('UserTarget', nil)
        user_project = Xcodeproj::Project.new('path')
        e = lambda { TargetInspector.new(target_definition).send(:compute_targets, user_project) }.should.raise Informative
        e.message.should.match /Unable to find a target named/
      end

      it 'returns the first target of the project if the target definition is named default' do
        target_definition = Podfile::TargetDefinition.new('Pods', nil)
        target_definition.link_with_first_target = true
        user_project = Xcodeproj::Project.new('path')
        user_project.new_target(:application, 'FirstTarget', :ios)
        user_project.new_target(:application, 'UserTarget', :ios)

        targets = TargetInspector.new(target_definition).send(:compute_targets, user_project)
        targets.map(&:name).should == ['FirstTarget']
      end

      it 'raises if the default target definition cannot be linked because there are no user targets' do
        target_definition = Podfile::TargetDefinition.new(:default, nil)
        user_project = Xcodeproj::Project.new('path')
        e = lambda { TargetInspector.new(target_definition).send(:compute_targets, user_project) }.should.raise Informative
        e.message.should.match /Unable to find a target/
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

        configurations = TargetInspector.new(target_definition).send(:compute_build_configurations, user_targets)
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

        configurations = TargetInspector.new(target_definition).send(:compute_build_configurations, user_targets)
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

        archs = TargetInspector.new(target_definition).send(:compute_archs, user_targets)
        archs.should == 'armv7'
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

        archs = TargetInspector.new(target_definition).send(:compute_archs, user_targets)
        archs.should == 'armv7'
      end

      it 'handles an Array of ARCHs defined in a single user target' do
        user_project = Xcodeproj::Project.new('path')
        target = user_project.new_target(:application, 'Target', :ios)
        target.build_configuration_list.set_setting('ARCHS', %w(armv7 i386))

        target_definition = Podfile::TargetDefinition.new(:default, nil)
        target_definition.set_platform(:ios, '4.0')
        user_targets = [target]

        archs = TargetInspector.new(target_definition).send(:compute_archs, user_targets)
        %w(armv7 i386).each { |a| archs.should.include a }
      end

      it 'handles an Array of ARCHs defined multiple user targets' do
        user_project = Xcodeproj::Project.new('path')
        targeta = user_project.new_target(:application, 'Target', :ios)
        targeta.build_configuration_list.set_setting('ARCHS', %w(armv7 armv7s))
        targetb = user_project.new_target(:application, 'Target', :ios)
        targetb.build_configuration_list.set_setting('ARCHS', %w(armv7 i386))

        target_definition = Podfile::TargetDefinition.new(:default, nil)
        target_definition.set_platform(:ios, '4.0')
        user_targets = [targeta, targetb]

        archs = TargetInspector.new(target_definition).send(:compute_archs, user_targets)
        %w(armv7 armv7s i386).each { |a| archs.should.include a }
      end
    end

    #--------------------------------------#

    describe '#compute_platform' do
      it 'returns the platform specified in the target definition' do
        target_definition = Podfile::TargetDefinition.new(:default, nil)
        target_definition.set_platform(:ios, '4.0')
        user_targets = []

        configurations = TargetInspector.new(target_definition).send(:compute_platform, user_targets)
        configurations.should == Platform.new(:ios, '4.0')
      end

      it 'infers the platform from the user targets' do
        user_project = Xcodeproj::Project.new('path')
        target = user_project.new_target(:application, 'Target', :ios)
        target.build_configuration_list.set_setting('SDKROOT', 'iphoneos')
        target.build_configuration_list.set_setting('IPHONEOS_DEPLOYMENT_TARGET', '4.0')

        target_definition = Podfile::TargetDefinition.new(:default, nil)
        user_targets = [target]

        configurations = TargetInspector.new(target_definition).send(:compute_platform, user_targets)
        configurations.should == Platform.new(:ios, '4.0')
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

        configurations = TargetInspector.new(target_definition).send(:compute_platform, user_targets)
        configurations.should == Platform.new(:ios, '4.0')
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
        e = lambda { TargetInspector.new(target_definition).send(:compute_platform, user_targets) }.should.raise Informative
        e.message.should.match /Targets with different platforms/
      end
    end
  end
end
