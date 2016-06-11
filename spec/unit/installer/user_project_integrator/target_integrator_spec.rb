require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe TargetIntegrator = Installer::UserProjectIntegrator::TargetIntegrator do
    describe 'In general' do
      # The project contains a `PBXReferenceProxy` in the build files of the
      # frameworks build phase which implicitly checks for the robustness of
      # the detection of the target.
      #
      before do
        project_path = SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
        @project = Xcodeproj::Project.open(project_path)
        Project.new(config.sandbox.project_path).save
        @target = @project.targets.first
        target_definition = Podfile::TargetDefinition.new('Pods', nil)
        target_definition.abstract = false
        @pod_bundle = AggregateTarget.new(target_definition, config.sandbox)
        @pod_bundle.user_project = @project
        @pod_bundle.client_root = project_path.dirname
        @pod_bundle.user_target_uuids = [@target.uuid]
        configuration = Xcodeproj::Config.new(
          'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) COCOAPODS=1',
        )
        @pod_bundle.xcconfigs['Debug'] = configuration
        @pod_bundle.xcconfigs['Release'] = configuration
        @target_integrator = TargetIntegrator.new(@pod_bundle)
        @target_integrator.private_methods.grep(/^update_to_cocoapods_/).each do |method|
          @target_integrator.stubs(method)
        end
        @phase_prefix = Installer::UserProjectIntegrator::TargetIntegrator::BUILD_PHASE_PREFIX
        @embed_framework_phase_name = @phase_prefix +
          Installer::UserProjectIntegrator::TargetIntegrator::EMBED_FRAMEWORK_PHASE_NAME
      end

      describe '#integrate!' do
        it 'set the CocoaPods xcconfigs' do
          TargetIntegrator::XCConfigIntegrator.expects(:integrate).with(@pod_bundle, [@target])
          @target_integrator.integrate!
        end

        it 'allows the xcconfig integrator to edit already integrated targets if needed' do
          TargetIntegrator::XCConfigIntegrator.expects(:integrate).with(@pod_bundle, [@target])
          @target_integrator.integrate!
        end

        it 'fixes the copy resource scripts of legacy installations' do
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase_name = @phase_prefix + Installer::UserProjectIntegrator::TargetIntegrator::COPY_PODS_RESOURCES_PHASE_NAME
          phase = target.shell_script_build_phases.find { |bp| bp.name == phase_name }
          phase.shell_script = %("${SRCROOT}/../Pods/Pods-resources.sh"\n)
          @target_integrator.integrate!
          phase.shell_script.strip.should == '"${SRCROOT}/../Pods/Target Support Files/Pods/Pods-resources.sh"'
        end

        it 'adds references to the Pods static libraries to the Frameworks group' do
          @target_integrator.integrate!
          @target_integrator.send(:user_project)['Frameworks/libPods.a'].should.not.be.nil
        end

        it 'adds the libPods static library to the "Link binary with libraries" build phase of each target' do
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.frameworks_build_phase
          build_file = phase.files.find { |f| f.file_ref.path == 'libPods.a' }
          build_file.should.not.be.nil
        end

        it 'adds references to the Pods static framework to the Frameworks group' do
          @pod_bundle.stubs(:requires_frameworks? => true)
          @target_integrator.integrate!
          @target_integrator.send(:user_project)['Frameworks/Pods.framework'].should.not.be.nil
        end

        it 'adds the Pods static framework to the "Link binary with libraries" build phase of each target' do
          @pod_bundle.stubs(:requires_frameworks? => true)
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.frameworks_build_phase
          build_file = phase.files.find { |f| f.file_ref.path == 'Pods.framework' }
          build_file.should.not.be.nil
        end

        it 'adds a Copy Pods Resources build phase to each target' do
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase_name = @phase_prefix + Installer::UserProjectIntegrator::TargetIntegrator::COPY_PODS_RESOURCES_PHASE_NAME
          phase = target.shell_script_build_phases.find { |bp| bp.name == phase_name }
          phase.shell_script.strip.should == '"${SRCROOT}/../Pods/Target Support Files/Pods/Pods-resources.sh"'
        end

        it 'adds a Check Manifest.lock build phase to each target' do
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase_name = @phase_prefix + Installer::UserProjectIntegrator::TargetIntegrator::CHECK_MANIFEST_PHASE_NAME
          phase = target.shell_script_build_phases.find { |bp| bp.name == phase_name }
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
          phase_name = @phase_prefix + Installer::UserProjectIntegrator::TargetIntegrator::CHECK_MANIFEST_PHASE_NAME
          phase = target.build_phases.find { |bp| bp.name == phase_name }
          target.build_phases.first.should.equal? phase
        end

        it 'does not perform the integration if there are no targets to integrate' do
          Installer::UserProjectIntegrator::TargetIntegrator::XCConfigIntegrator.
            integrate(@pod_bundle, @target_integrator.send(:native_targets))
          @target_integrator.stubs(:native_targets).returns([])
          frameworks = @target_integrator.send(:user_project).frameworks_group.children
          @target_integrator.integrate!
          @target_integrator.send(:user_project).frameworks_group.children.should == frameworks
        end

        it 'adds an embed frameworks build phase if frameworks are used' do
          @pod_bundle.stubs(:requires_frameworks? => true)
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == false
        end

        it 'adds an embed frameworks build phase by default' do
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == false
        end

        it 'does not add an embed frameworks build phase if the target to integrate is a framework' do
          @pod_bundle.stubs(:requires_frameworks? => true)
          target = @target_integrator.send(:native_targets).first
          target.stubs(:symbol_type).returns(:framework)
          @target_integrator.integrate!
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == true
        end

        it 'does not add an embed frameworks build phase if the target to integrate is an app extension' do
          @pod_bundle.stubs(:requires_frameworks? => true)
          target = @target_integrator.send(:native_targets).first
          target.stubs(:symbol_type).returns(:app_extension)
          @target_integrator.integrate!
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == true
        end

        it 'does not add an embed frameworks build phase if the target to integrate is a watch extension' do
          @pod_bundle.stubs(:requires_frameworks? => true)
          target = @target_integrator.send(:native_targets).first
          target.stubs(:symbol_type).returns(:watch_extension)
          @target_integrator.integrate!
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == true
        end

        it 'adds an embed frameworks build phase if the target to integrate is a watchOS 2 extension' do
          @pod_bundle.stubs(:requires_frameworks? => true)
          target = @target_integrator.send(:native_targets).first
          target.stubs(:symbol_type).returns(:watch2_extension)
          @target_integrator.integrate!
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == false
        end

        it 'adds an embed frameworks build phase if the target to integrate is a UI Test bundle' do
          @pod_bundle.stubs(:requires_frameworks? => true)
          target = @target_integrator.send(:native_targets).first
          target.stubs(:symbol_type).returns(:ui_test_bundle)
          @target_integrator.integrate!
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == false
        end

        it 'does not remove existing embed frameworks build phases from integrated framework targets' do
          @pod_bundle.stubs(:requires_frameworks? => true)
          @target_integrator.integrate!
          @pod_bundle.stubs(:requires_frameworks? => false)
          target = @target_integrator.send(:native_targets).first
          @target_integrator.integrate!
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.should.not.be.nil
        end

        it 'does not remove existing embed frameworks build phases if frameworks are not used anymore' do
          @pod_bundle.stubs(:requires_frameworks? => true)
          @target_integrator.integrate!
          @pod_bundle.stubs(:requires_frameworks? => false)
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == false
        end

        it 'removes embed frameworks build phases from app extension targets' do
          @pod_bundle.stubs(:requires_frameworks? => true)
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == false
          target.stubs(:symbol_type).returns(:app_extension)
          @target_integrator.integrate!
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == true
        end

        it 'removes embed frameworks build phases from watch extension targets' do
          @pod_bundle.stubs(:requires_frameworks? => true)
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == false
          target.stubs(:symbol_type).returns(:watch_extension)
          @target_integrator.integrate!
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == true
        end

        it 'removes embed frameworks build phases from framework targets' do
          @pod_bundle.stubs(:requires_frameworks? => true)
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == false
          target.stubs(:symbol_type).returns(:framework)
          @target_integrator.integrate!
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == true
        end
      end

      describe 'Private helpers' do
        it 'returns the native targets associated with the Pod bundle' do
          @target_integrator.send(:native_targets).map(&:name).should == %w( SampleProject          )
        end

        it 'is robust against other types of references in the build files of the frameworks build phase' do
          build_file = @project.new(Xcodeproj::Project::PBXBuildFile)
          build_file.file_ref = @project.new(Xcodeproj::Project::PBXVariantGroup)
          @target_integrator.stubs(:user_project).returns(@project)
          @target.frameworks_build_phase.files << build_file
          @target_integrator.send(:native_targets).map(&:name).should == %w( SampleProject          )
        end

        it 'is robust against build files with missing file references' do
          build_file = @project.new(Xcodeproj::Project::PBXBuildFile)
          build_file.file_ref = nil
          @target_integrator.stubs(:user_project).returns(@project)
          @target.frameworks_build_phase.files << build_file
          @target_integrator.send(:native_targets).map(&:name).should == %w( SampleProject          )
        end
      end
    end
  end
end
