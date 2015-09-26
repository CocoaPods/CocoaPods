require File.expand_path('../../../../../spec_helper', __FILE__)

module Pod
  describe XCConfigIntegrator = Installer::UserProjectIntegrator::TargetIntegrator::XCConfigIntegrator do
    before do
      project_path = SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
      @project = Xcodeproj::Project.open(project_path)
      Xcodeproj::Project.new(config.sandbox.project_path).save
      @target = @project.targets.first
      target_definition = Podfile::TargetDefinition.new('Pods', nil)
      target_definition.link_with_first_target = true
      @pod_bundle = AggregateTarget.new(target_definition, config.sandbox)
      @pod_bundle.user_project_path = project_path
      @pod_bundle.client_root = project_path.dirname
      @pod_bundle.user_target_uuids = [@target.uuid]
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
  end
end
