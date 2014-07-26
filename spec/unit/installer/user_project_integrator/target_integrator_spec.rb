require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe TargetIntegrator = Installer::UserProjectIntegrator::TargetIntegrator do
    describe "In general" do

      # The project contains a `PBXReferenceProxy` in the build files of the
      # frameworks build phase which implicitly checks for the robustness of
      # the detection of the target.
      #
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
        configuration = Xcodeproj::Config.new({
          'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) COCOAPODS=1'
        })
        @pod_bundle.xcconfigs['Debug'] = configuration
        @pod_bundle.xcconfigs['Test'] = configuration
        @pod_bundle.xcconfigs['Release'] = configuration
        @pod_bundle.xcconfigs['App Store'] = configuration
        @target_integrator = TargetIntegrator.new(@pod_bundle)
      end

      describe '#integrate!' do
        it 'set the CocoaPods xcconfigs' do
          TargetIntegrator::XCConfigIntegrator.expects(:integrate).with(@pod_bundle, [@target])
          @target_integrator.integrate!
        end

        it 'allows the xcconfig integrator to edit already integrated targets if needed' do
          @target_integrator.stubs(:native_targets_to_integrate).returns([])
          TargetIntegrator::XCConfigIntegrator.expects(:integrate).with(@pod_bundle, [@target])
          @target_integrator.integrate!
        end

        it 'adds references to the Pods static libraries to the Frameworks group' do
          @target_integrator.integrate!
          @target_integrator.send(:user_project)["Frameworks/libPods.a"].should.not == nil
        end

        it 'adds the libPods static library to the "Link binary with libraries" build phase of each target' do
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.frameworks_build_phase
          ref = phase.files.find { |f| f.file_ref.path == 'libPods.a'}
          ref.should.not.be.nil
        end

        it 'adds a Copy Pods Resources build phase to each target' do
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == "Copy Pods Resources" }
          phase.shell_script.strip.should == "\"${SRCROOT}/../Pods/Pods-resources.sh\""
        end

        it 'adds a Check Manifest.lock build phase to each target' do
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == "Check Pods Manifest.lock" }
          phase.shell_script.should == <<-EOS.strip_heredoc
          diff "${PODS_ROOT}/../Podfile.lock" "${PODS_ROOT}/Manifest.lock" > /dev/null
          if [[ $? != 0 ]] ; then
              cat << EOM
          error: The sandbox is not in sync with the Podfile.lock. Run 'pod install' or update your CocoaPods installation.
          EOM
              exit 1
          fi
          EOS
        end

        it 'adds the Check Manifest.lock build phase as the first build phase' do
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          target.build_phases.first
          phase = target.build_phases.find { |bp| bp.name == "Check Pods Manifest.lock" }
          target.build_phases.first.should.equal? phase
        end

        it 'does not perform the integration if there are no targets to integrate' do
          @target_integrator.stubs(:native_targets_to_integrate).returns([])
          @target_integrator.expects(:add_pods_library).never
          @target_integrator.expects(:add_copy_resources_script_phase).never
          @target_integrator.expects(:save_user_project).never
          @target_integrator.integrate!
        end
      end

      describe 'Private helpers' do
        it 'returns the native targets associated with the Pod bundle' do
          @target_integrator.send(:native_targets).map(&:name).should == %w[ SampleProject ]
        end

        it 'returns the targets that need to be integrated' do
          pods_library = @project.frameworks_group.new_product_ref_for_target('Pods', :static_library)
          @target.frameworks_build_phase.add_file_reference(pods_library)
          @target_integrator.stubs(:user_project).returns(@project)
          @target_integrator.send(:native_targets_to_integrate).map(&:name).should.be.empty
        end

        it 'is robust against other types of references in the build files of the frameworks build phase' do
          build_file = @project.new(Xcodeproj::Project::PBXBuildFile)
          build_file.file_ref = @project.new(Xcodeproj::Project::PBXVariantGroup)
          @target_integrator.stubs(:user_project).returns(@project)
          @target.frameworks_build_phase.files << build_file
          @target_integrator.send(:native_targets).map(&:name).should == %w[ SampleProject ]
        end

        it 'is robust against build files with missing file references' do
          build_file = @project.new(Xcodeproj::Project::PBXBuildFile)
          build_file.file_ref = nil
          @target_integrator.stubs(:user_project).returns(@project)
          @target.frameworks_build_phase.files << build_file
          @target_integrator.send(:native_targets).map(&:name).should == %w[ SampleProject ]
        end
      end
    end
  end
end
