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
      @pod_bundle.user_project_path  = project_path
      @pod_bundle.client_root = project_path.dirname
      @pod_bundle.user_target_uuids  = [@target.uuid]
      configuration = Xcodeproj::Config.new(
        'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) COCOAPODS=1'
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
      File.expects(:exist?).returns(true)
      File.expects(:delete).with(path)
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

  end
end
