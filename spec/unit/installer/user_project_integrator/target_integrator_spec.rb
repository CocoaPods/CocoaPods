require File.expand_path('../../../../spec_helper', __FILE__)

module Pod

  describe TargetIntegrator = Installer::UserProjectIntegrator::TargetIntegrator do

    describe "In general" do
      before do
        sample_project_path = SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
        @sample_project = Xcodeproj::Project.new sample_project_path
        @target = @sample_project.targets.first
        target_definition = Podfile::TargetDefinition.new(:default, nil, nil)
        @lib = Library.new(target_definition)
        @lib.user_project_path = sample_project_path
        pods_project = Project.new()
        @lib.target = pods_project.new_target(:static_library, target_definition.label, :ios)
        @lib.user_target_uuids  = [@target.uuid]
        @lib.support_files_root = config.sandbox.root
        @lib.user_project_path  = sample_project_path
        @target_integrator = TargetIntegrator.new(@lib)
      end

      it 'returns the targets that need to be integrated' do
        @target_integrator.targets.map(&:name).should == %w[ SampleProject ]
      end

      it 'returns the targets that need to be integrated' do
        pods_library = @sample_project.frameworks_group.new_static_library('Pods')
        @target.frameworks_build_phase.add_file_reference(pods_library)
        Xcodeproj::Project.any_instance.stubs(:targets).returns([@target])
        @target_integrator.targets.map(&:name).should.be.empty?
      end

      it 'does not perform the integration if there are no targets to integrate' do
        @target_integrator.stubs(:targets).returns([])
        @target_integrator.expects(:add_xcconfig_base_configuration).never
        @target_integrator.expects(:add_pods_library).never
        @target_integrator.expects(:add_copy_resources_script_phase).never
        @target_integrator.expects(:save_user_project).never
        @target_integrator.integrate!
      end

      before do
        @target_integrator.integrate!
      end

      it 'sets the Pods xcconfig as the base config for each build configuration' do
        xcconfig_file = @sample_project.files.find { |f| f.path == @lib.xcconfig_relative_path }
        @target.build_configurations.each do |config|
          config.base_configuration_reference.should == xcconfig_file
        end
      end

      it 'adds references to the Pods static libraries to the Frameworks group' do
        @target_integrator.user_project["Frameworks/libPods.a"].should.not == nil
      end

      it 'adds the libPods static library to the "Link binary with libraries" build phase of each target' do
        target = @target_integrator.targets.first
        target.frameworks_build_phase.files.find { |f| f.file_ref.path == 'libPods.a'}.should.not == nil
      end

      it 'adds a Copy Pods Resources build phase to each target' do
        target = @target_integrator.targets.first
        phase = target.shell_script_build_phases.find { |bp| bp.name == "Copy Pods Resources" }
        phase.shell_script.strip.should == "\"${SRCROOT}/../Pods/Pods-resources.sh\""
      end

    end
  end
end
