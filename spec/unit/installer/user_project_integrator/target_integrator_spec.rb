require File.expand_path('../../../../spec_helper', __FILE__)

module Pod

  describe TargetIntegrator = Installer::UserProjectIntegrator::TargetIntegrator do

    describe "In general" do

      before do
        project_path = SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
        @project = Xcodeproj::Project.open(project_path)
        @native_target = @project.targets.first
        @target = Target.new('Pods')
        @target.user_project_path  = project_path
        @target.user_target_uuids  = [@native_target.uuid]
        @target.xcconfig_path  = config.sandbox.root + 'Pods.xcconfig'
        @target.copy_resources_script_path  = config.sandbox.root + 'Pods-resources.sh'
        @sut = TargetIntegrator.new(@target)
      end

      #-----------------------------------------------------------------------#

      describe "#integrate!" do

        it 'returns the targets that need to be integrated' do
          pods_library = @project.frameworks_group.new_product_ref_for_target('Pods', :static_library)
          @native_target.frameworks_build_phase.add_file_reference(pods_library)
          @sut.stubs(:user_project).returns(@project)
          @sut.send(:native_targets).map(&:name).should.be.empty?
        end

        before do
          @sut.integrate!
        end

        it 'sets the Pods xcconfig as the base config for each build configuration' do
          xcconfig_file = @project.files.find { |f| f.real_path == @target.xcconfig_path }
          @native_target.build_configurations.each do |config|
            config.base_configuration_reference.should == xcconfig_file
          end
        end

        it 'adds references to the Pods static libraries to the Frameworks group' do
          @sut.send(:user_project)["Frameworks/libPods.a"].should.not == nil
        end

        it 'adds the libPods static library to the "Link binary with libraries" build phase of each target' do
          target = @sut.send(:native_targets).first
          target.frameworks_build_phase.files.find { |f| f.file_ref.path == 'libPods.a'}.should.not == nil
        end

        it 'adds a Copy Pods Resources build phase to each target' do
          target = @sut.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == "Copy Pods Resources" }
          phase.shell_script.strip.should == '"${SRCROOT}/../Pods/Pods-resources.sh"'
        end

        it 'adds a Check Manifest.lock build phase to each target' do
          target = @sut.send(:native_targets).first
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
          target = @sut.send(:native_targets).first
          phase = target.build_phases.find { |bp| bp.name == "Check Pods Manifest.lock" }
          target.build_phases.first.should.equal? phase
        end

      end

      #-----------------------------------------------------------------------#

      describe "Private helpers" do

        describe "#native_targets" do

          it 'returns the targets that need to be integrated' do
            @sut.send(:native_targets).map(&:name).should == %w[ SampleProject ]
          end

          it 'returns the targets that need to be integrated' do
            pods_library = @project.frameworks_group.new_product_ref_for_target('Pods', :static_library)
            @native_target.frameworks_build_phase.add_file_reference(pods_library)
            @sut.stubs(:user_project).returns(@project)
            @sut.send(:native_targets).map(&:name).should.be.empty?
          end

          it 'is robust against other types of references in the build files of the frameworks build phase' do
            build_file = @project.new(Xcodeproj::Project::PBXBuildFile)
            build_file.file_ref = @project.new(Xcodeproj::Project::PBXVariantGroup)
            @sut.stubs(:user_project).returns(@project)
            @native_target.frameworks_build_phase.files << build_file
            @sut.send(:native_targets).map(&:name).should == %w[ SampleProject ]
          end

          it 'is robust against build files with missing file references' do
            build_file = @project.new(Xcodeproj::Project::PBXBuildFile)
            build_file.file_ref = nil
            @sut.stubs(:user_project).returns(@project)
            @native_target.frameworks_build_phase.files << build_file
            @sut.send(:native_targets).map(&:name).should == %w[ SampleProject ]
          end

        end

        it 'does not perform the integration if there are no targets to integrate' do
          @sut.stubs(:native_targets).returns([])
          @sut.expects(:set_xcconfig).never
          @sut.expects(:add_pods_library).never
          @sut.expects(:add_copy_resources_script_phase).never
          @sut.expects(:save_user_project).never
          @sut.integrate!
        end

      end

      #-----------------------------------------------------------------------#

    end
  end
end
