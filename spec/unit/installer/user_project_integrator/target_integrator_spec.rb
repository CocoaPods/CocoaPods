require File.expand_path('../../../../spec_helper', __FILE__)

module Pod

  describe TargetIntegrator = Installer::UserProjectIntegrator::TargetIntegrator do

    describe "In general" do

      # The project contains a `PBXReferenceProxy` in the build files of the
      # frameworks build phase which implicitly checks for the robustness of
      # the detection of the target.
      #
      before do
        sample_project_path = SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
        @sample_project = Xcodeproj::Project.new sample_project_path
        Xcodeproj::Project.new.save_as(config.sandbox.project_path)
        @target = @sample_project.targets.first
        target_definition = Podfile::TargetDefinition.new('Pods', nil)
        target_definition.link_with_first_target = true
        @lib = AggregateTarget.new(target_definition, config.sandbox)
        @lib.user_project_path  = sample_project_path
        @lib.client_root = sample_project_path.dirname
        @lib.user_target_uuids  = [@target.uuid]
        @target_integrator = TargetIntegrator.new(@lib)
      end

      it 'returns the targets that need to be integrated' do
        @target_integrator.native_targets.map(&:name).should == %w[ SampleProject ]
      end

      it 'returns the targets that need to be integrated' do
        pods_library = @sample_project.frameworks_group.new_static_library('Pods')
        @target.frameworks_build_phase.add_file_reference(pods_library)
        @target_integrator.stubs(:user_project).returns(@sample_project)
        @target_integrator.native_targets.map(&:name).should.be.empty?
      end

      it 'is robust against other types of references in the build files of the frameworks build phase' do
        build_file = @sample_project.new(Xcodeproj::Project::PBXBuildFile)
        build_file.file_ref = @sample_project.new(Xcodeproj::Project::PBXVariantGroup)
        @target_integrator.stubs(:user_project).returns(@sample_project)
        @target.frameworks_build_phase.files << build_file
        @target_integrator.native_targets.map(&:name).should == %w[ SampleProject ]
      end

      it 'is robust against build files with missing file references' do
        build_file = @sample_project.new(Xcodeproj::Project::PBXBuildFile)
        build_file.file_ref = nil
        @target_integrator.stubs(:user_project).returns(@sample_project)
        @target.frameworks_build_phase.files << build_file
        @target_integrator.native_targets.map(&:name).should == %w[ SampleProject ]
      end

      it 'does not perform the integration if there are no targets to integrate' do
        @target_integrator.stubs(:native_targets).returns([])
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
        target = @target_integrator.native_targets.first
        target.frameworks_build_phase.files.find { |f| f.file_ref.path == 'libPods.a'}.should.not == nil
      end

      it 'adds a Copy Pods Resources build phase to each target' do
        target = @target_integrator.native_targets.first
        phase = target.shell_script_build_phases.find { |bp| bp.name == "Copy Pods Resources" }
        phase.shell_script.strip.should == "\"${SRCROOT}/../Pods/Generated/Pods-resources.sh\""
      end

      it 'adds a Check Manifest.lock build phase to each target' do
        target = @target_integrator.native_targets.first
        phase = target.shell_script_build_phases.find { |bp| bp.name == "Check Pods Manifest.lock" }
        phase.shell_script.should == <<-EOS.strip_heredoc
          diff "${PODS_ROOT}/../../Podfile.lock" "${PODS_ROOT}/Manifest.lock" > /dev/null
          if [[ $? != 0 ]] ; then
              cat << EOM
          error: The sandbox is not in sync with the Podfile.lock. Run 'pod install' or update your CocoaPods installation.
          EOM
              exit 1
          fi
        EOS
      end

      it 'adds the Check Manifest.lock build phase as the first build phase' do
        target = @target_integrator.native_targets.first
        phase = target.build_phases.find { |bp| bp.name == "Check Pods Manifest.lock" }
        target.build_phases.first.should.equal? phase
      end

    end
  end
end
