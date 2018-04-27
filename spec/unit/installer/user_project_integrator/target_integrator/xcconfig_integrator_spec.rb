require File.expand_path('../../../../../spec_helper', __FILE__)

module Pod
  describe XCConfigIntegrator = Installer::UserProjectIntegrator::TargetIntegrator::XCConfigIntegrator do
    before do
      project_path = SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
      @project = Xcodeproj::Project.open(project_path)
      Project.new(config.sandbox.project_path).save
      @target = @project.targets.first
      target_definition = Podfile::TargetDefinition.new('Pods', nil)
      target_definition.abstract = false
      @pod_bundle = AggregateTarget.new(config.sandbox, false, {}, [], Platform.ios, target_definition, project_path.dirname, @project, [@target.uuid], {})
      configuration = Xcodeproj::Config.new(
        'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) COCOAPODS=1',
      )
      @pod_bundle.xcconfigs['Debug'] = configuration
      @pod_bundle.xcconfigs['Test'] = configuration
      @pod_bundle.xcconfigs['Release'] = configuration
      @pod_bundle.xcconfigs['App Store'] = configuration
    end

    it 'cleans the xcconfig used up to CocoaPods 0.33.1' do
      path = @pod_bundle.xcconfig_path
      file_ref = @project.new_file(path)
      config = @target.build_configuration_list['Release']
      config.base_configuration_reference = file_ref
      XCConfigIntegrator.integrate(@pod_bundle, [@target])
      @project.files.find { |f| f.path == path }.should.be.nil
    end

    it 'sets the Pods xcconfig as the base config for each build configuration' do
      XCConfigIntegrator.integrate(@pod_bundle, [@target])
      @target.build_configurations.each do |config|
        xcconfig_file = @project.files.find { |f| f.path == @pod_bundle.xcconfig_relative_path(config.name) }
        config.base_configuration_reference.should == xcconfig_file
      end
    end

    it 'does not duplicate the file reference to the CocoaPods xcconfig in the user project' do
      path = @pod_bundle.xcconfig_relative_path('Release')
      existing = @project.new_file(path)
      XCConfigIntegrator.integrate(@pod_bundle, [@target])
      config = @target.build_configuration_list['Release']
      config.base_configuration_reference.should.equal existing
    end

    it 'logs a warning and does not set the Pods xcconfig as the base config if the user ' \
       'has already set a config of their own' do
      sample_config = @project.new_file('SampleConfig.xcconfig')
      @target.build_configurations.each do |config|
        config.base_configuration_reference = sample_config
      end
      XCConfigIntegrator.integrate(@pod_bundle, [@target])
      @target.build_configurations.each do |config|
        config.base_configuration_reference.should == sample_config
      end

      UI.warnings.should.match /not set.*base configuration/
    end

    it 'sets the Pods xcconfig as the base config on other targets if no base has been set yet' do
      target = @project.targets[1]
      XCConfigIntegrator.integrate(@pod_bundle, [@target, target])
      target.build_configurations.each do |config|
        config.base_configuration_reference.path.should.include 'Pods'
      end

      UI.warnings.should.not.match /not set.*base configuration/
    end

    it 'does not log a warning if the user has set a xcconfig of their own that includes the Pods config' do
      sample_config = @project.new_file('SampleConfig.xcconfig')
      File.open(sample_config.real_path, 'w') do |file|
        @target.build_configurations.each do |config|
          file.write("\#include \"#{@pod_bundle.xcconfig_relative_path(config.name)}\"\n")
        end
      end
      @target.build_configurations.each do |config|
        config.base_configuration_reference = sample_config
      end
      XCConfigIntegrator.integrate(@pod_bundle, [@target])
      @target.build_configurations.each do |config|
        config.base_configuration_reference.should == sample_config
      end

      UI.warnings.should.not.match /not set.*base configuration/
    end

    it 'does not log a warning if the existing xcconfig is identical to the Pods config' do
      sample_config = @project.new_file('SampleConfig.xcconfig')
      File.write(sample_config.real_path, 'sample config content.')
      @target.build_configurations.each do |config|
        config.base_configuration_reference = sample_config
      end
      XCConfigIntegrator.integrate(@pod_bundle, [@target])
      @target.build_configurations.each do |config|
        config.base_configuration_reference.should == sample_config
      end

      UI.warnings.should.not.match /not set.*base configuration/
    end

    it 'does not log a warning if the user has set a xcconfig of their own that includes the silence warnings string' do
      SILENCE_TOKEN = '// @COCOAPODS_SILENCE_WARNINGS@ //'
      sample_config = @project.new_file('SampleConfig.xcconfig')
      File.open(sample_config.real_path, 'w') do |file|
        file.write("#{SILENCE_TOKEN}\n")
      end
      @target.build_configurations.each do |config|
        config.base_configuration_reference = sample_config
      end
      XCConfigIntegrator.integrate(@pod_bundle, [@target])
      @target.build_configurations.each do |config|
        config.base_configuration_reference.should == sample_config
      end

      UI.warnings.should.not.match /not set.*base configuration/
    end

    it 'handles when xcconfig is set to another sandbox xcconfig' do
      group = @project.new_group('Pods')

      old_config = group.new_file('../Pods/Target Support Files/Pods-Foo/SampleConfig.xcconfig')
      @target.build_configurations.each do |config|
        config.base_configuration_reference = old_config
      end
      XCConfigIntegrator.integrate(@pod_bundle, [@target])
      @target.build_configurations.each do |config|
        config.base_configuration_reference.should.not == old_config
        config.base_configuration_reference.path.should == @pod_bundle.xcconfig_relative_path(config.name)
      end

      @pod_bundle.stubs(:label).returns('Pods-Foo')
      old_config = group.new_file('../Pods/Target Support Files/Pods/SampleConfig.xcconfig')
      @target.build_configurations.each do |config|
        config.base_configuration_reference = old_config
      end
      XCConfigIntegrator.integrate(@pod_bundle, [@target])
      @target.build_configurations.each do |config|
        config.base_configuration_reference.should.not == old_config
        config.base_configuration_reference.path.should == @pod_bundle.xcconfig_relative_path(config.name)
      end

      UI.warnings.should.be.empty
    end
  end
end
