require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe UserProjectIntegrator = Installer::UserProjectIntegrator do

    describe 'In general' do

      before do
        @sample_project_path = SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
        sample_project_path = @sample_project_path
        @podfile = Podfile.new do
          platform :ios
          xcodeproj sample_project_path
          pod 'JSONKit'
          target :empty do

          end
        end
        config.sandbox.project = Project.new(config.sandbox.project_path)
        Xcodeproj::Project.new(config.sandbox.project_path).save
        @target = AggregateTarget.new(@podfile.target_definitions['Pods'], config.sandbox)
        @target.client_root = sample_project_path.dirname
        @target.user_project_path  = sample_project_path
        @target.user_target_uuids  = ['A346496C14F9BE9A0080D870']
        empty_library = AggregateTarget.new(@podfile.target_definitions[:empty], config.sandbox)
        @integrator = UserProjectIntegrator.new(@podfile, config.sandbox, temporary_directory, [@target, empty_library])
      end

      #-----------------------------------------------------------------------#

      describe 'In general' do
        before do
          @integrator.stubs(:warn_about_xcconfig_overrides)
        end

        it 'adds the Pods project to the workspace' do
          UserProjectIntegrator::TargetIntegrator.any_instance.stubs(:integrate!)
          @integrator.integrate!
          workspace_path = @integrator.send(:workspace_path)
          workspace = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)
          pods_project_ref = workspace.file_references.find do |ref|
            ref.path =~ /Pods.xcodeproj/
          end
          pods_project_ref.should.not.be.nil
        end

        it 'integrates the user targets' do
          UserProjectIntegrator::TargetIntegrator.any_instance.expects(:integrate!)
          @integrator.integrate!
        end

        it 'warns if the podfile does not contain any dependency' do
          Podfile::TargetDefinition.any_instance.stubs(:empty?).returns(true)
          @integrator.integrate!
          UI.warnings.should.include?('The Podfile does not contain any dependencies')
        end

        describe '#warn_about_xcconfig_overrides' do
          shared 'warn_about_xcconfig_overrides' do
            target_config = stub(:name => 'Release', :build_settings => @user_target_build_settings)
            user_target = stub(:name => 'SampleProject', :build_configurations => [target_config])
            @target.stubs(:user_targets).returns([user_target])

            @target.xcconfigs['Release'] = { 'GCC_PREPROCESSOR_DEFINITIONS' => 'COCOAPODS=1' }
            @integrator = UserProjectIntegrator.new(@podfile, config.sandbox, temporary_directory, [@target])

            @integrator.unstub(:warn_about_xcconfig_overrides)
            @integrator.send(:warn_about_xcconfig_overrides)
          end

          it 'check that the integrated target does not override the CocoaPods build settings' do
            @user_target_build_settings = { 'GCC_PREPROCESSOR_DEFINITIONS' => ['FLAG=1'] }
            behaves_like 'warn_about_xcconfig_overrides'
            UI.warnings.should.include 'The `SampleProject [Release]` target ' \
              'overrides the `GCC_PREPROCESSOR_DEFINITIONS` build setting'
          end

          it 'allows the use of the alternate form of the inherited flag' do
            @user_target_build_settings = { 'GCC_PREPROCESSOR_DEFINITIONS' => ['FLAG=1', '${inherited}'] }
            behaves_like 'warn_about_xcconfig_overrides'
            UI.warnings.should.not.include 'GCC_PREPROCESSOR_DEFINITIONS'
          end

          it 'allows build settings which inherit the settings form the CocoaPods xcconfig' do
            @user_target_build_settings = { 'GCC_PREPROCESSOR_DEFINITIONS' => ['FLAG=1', '$(inherited)'] }
            behaves_like 'warn_about_xcconfig_overrides'
            UI.warnings.should.not.include 'GCC_PREPROCESSOR_DEFINITIONS'
          end

          it "ignores certain build settings which don't inherit the settings form the CocoaPods xcconfig" do
            @user_target_build_settings = { 'CODE_SIGN_IDENTITY' => "Mac Developer" }
            behaves_like 'warn_about_xcconfig_overrides'
            UI.warnings.should.not.include 'CODE_SIGN_IDENTITY'
          end
        end

      end

      #-----------------------------------------------------------------------#

      describe 'Workspace creation' do

        it 'creates a new workspace if needed' do
          @integrator.send(:create_workspace)
          workspace_path = @integrator.send(:workspace_path)
          saved = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)
          saved.file_references.map(&:path).should == [
            'SampleProject/SampleProject.xcodeproj',
            'Pods/Pods.xcodeproj',
          ]
        end

        it 'updates an existing workspace if needed' do
          workspace_path = @integrator.send(:workspace_path)
          ref = Xcodeproj::Workspace::FileReference.new('SampleProject/SampleProject.xcodeproj', 'group')
          workspace = Xcodeproj::Workspace.new(ref)
          workspace.save_as(workspace_path)
          @integrator.send(:create_workspace)
          saved = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)
          saved.file_references.map(&:path).should == [
            'SampleProject/SampleProject.xcodeproj',
            'Pods/Pods.xcodeproj',
          ]
        end

        it "doesn't write the workspace if not needed" do
          file_references = [
            Xcodeproj::Workspace::FileReference.new('SampleProject/SampleProject.xcodeproj', 'group'),
            Xcodeproj::Workspace::FileReference.new('Pods/Pods.xcodeproj', 'group'),
          ]

          workspace = Xcodeproj::Workspace.new(file_references)
          workspace_path = @integrator.send(:workspace_path)
          workspace.save_as(workspace_path)
          Xcodeproj::Workspace.any_instance.expects(:save_as).never
          @integrator.send(:create_workspace)
        end

        it 'only appends projects to the workspace and never deletes one' do
          ref = Xcodeproj::Workspace::FileReference.new('user_added_project.xcodeproj', 'group')
          workspace = Xcodeproj::Workspace.new(ref)
          workspace_path = @integrator.send(:workspace_path)
          workspace.save_as(workspace_path)
          @integrator.send(:create_workspace)
          saved = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)
          saved.file_references.map(&:path).should == [
            'user_added_project.xcodeproj',
            'SampleProject/SampleProject.xcodeproj',
            'Pods/Pods.xcodeproj',
          ]
        end

        it 'preserves the order of the projects in the workspace' do
          file_references = [
            Xcodeproj::Workspace::FileReference.new('Pods/Pods.xcodeproj', 'group'),
            Xcodeproj::Workspace::FileReference.new('SampleProject/SampleProject.xcodeproj', 'group'),
          ]

          workspace = Xcodeproj::Workspace.new(file_references)
          workspace_path = @integrator.send(:workspace_path)
          workspace.save_as(workspace_path)
          @integrator.send(:create_workspace)
          saved = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)
          saved.file_references.map(&:path).should == [
            'Pods/Pods.xcodeproj',
            'SampleProject/SampleProject.xcodeproj',
          ]
        end

      end

      #-----------------------------------------------------------------------#

      describe 'Private Helpers' do

        it 'uses the path of the workspace defined in the podfile' do
          path = 'a_path'
          @podfile.workspace(path)
          workspace_path = @integrator.send(:workspace_path)
          workspace_path.to_s.should.end_with(path + '.xcworkspace')
          workspace_path.should.be.absolute
          workspace_path.class.should == Pathname
        end

        it 'names the workspace after the user project if needed' do
          @integrator.send(:workspace_path).should == temporary_directory + 'SampleProject.xcworkspace'
        end

        it 'raises if no workspace could be selected' do
          @integrator.expects(:user_project_paths).returns(%w(          project1 project2          ))
          e = lambda { @integrator.send(:workspace_path) }.should.raise Informative
        end

        it 'returns the paths of the user projects' do
          @integrator.send(:user_project_paths).should == [@sample_project_path]
        end

        it 'skips libraries with empty target definitions' do
          @integrator.targets.map(&:name).should == ['Pods', 'Pods-empty']
          @integrator.send(:targets_to_integrate).map(&:name).should == ['Pods']
        end

      end

      #-----------------------------------------------------------------------#

    end
  end
end
