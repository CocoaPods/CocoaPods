require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::UserProjectIntegrator do

    describe "In general" do

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
        config.sandbox.project = Project.new(config.sandbox, nil)
        Xcodeproj::Project.new.save_as(config.sandbox.project_path)
        @library = AggregateTarget.new(@podfile.target_definitions['Pods'], config.sandbox)
        @library.client_root = sample_project_path.dirname
        @library.user_project_path  = sample_project_path
        @library.user_target_uuids  = ['A346496C14F9BE9A0080D870']
        empty_library = AggregateTarget.new(@podfile.target_definitions[:empty], config.sandbox)
        @integrator = Installer::UserProjectIntegrator.new(@podfile, config.sandbox, temporary_directory, [@library, empty_library])
      end

      #-----------------------------------------------------------------------#

      describe "In general" do

        it "adds the Pods project to the workspace" do
          @integrator.integrate!
          workspace_path = @integrator.send(:workspace_path)
          workspace = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)
          workspace.projpaths.find { |path| path =~ /Pods.xcodeproj/ }.should.not.be.nil
        end

        it "integrates the user targets" do
          @integrator.integrate!
          user_project = Xcodeproj::Project.new(@sample_project_path)
          target = user_project.objects_by_uuid[@library.user_target_uuids.first]
          target.frameworks_build_phase.files.map(&:display_name).should.include('libPods.a')
        end

        it "warns if the podfile does not contain any dependency" do
          Podfile::TargetDefinition.any_instance.stubs(:empty?).returns(true)
          @integrator.integrate!
          UI.warnings.should.include?('The Podfile does not contain any dependencies')
        end

      end

      #-----------------------------------------------------------------------#

      describe "Workspace creation" do

        it "creates a new workspace if needed" do
          @integrator.send(:create_workspace)
          workspace_path = @integrator.send(:workspace_path)
          saved = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)
          saved.projpaths.should == [
            "SampleProject/SampleProject.xcodeproj",
            "Pods/Pods.xcodeproj"
          ]
        end

        it "updates an existing workspace if needed" do
          workspace_path = @integrator.send(:workspace_path)
          workspace = Xcodeproj::Workspace.new('SampleProject/SampleProject.xcodeproj')
          workspace.save_as(workspace_path)
          @integrator.send(:create_workspace)
          saved = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)
          saved.projpaths.should == [
            "SampleProject/SampleProject.xcodeproj",
            "Pods/Pods.xcodeproj"
          ]
        end

        it "doesn't write the workspace if not needed" do
          projpaths = [
            "SampleProject/SampleProject.xcodeproj",
            "Pods/Pods.xcodeproj"
          ]
          workspace = Xcodeproj::Workspace.new(projpaths)
          workspace_path = @integrator.send(:workspace_path)
          workspace.save_as(workspace_path)
          Xcodeproj::Workspace.expects(:save_as).never
          @integrator.send(:create_workspace)
        end

        it "only appends projects to the workspace and never deletes one" do
          workspace = Xcodeproj::Workspace.new('user_added_project.xcodeproj')
          workspace_path = @integrator.send(:workspace_path)
          workspace.save_as(workspace_path)
          @integrator.send(:create_workspace)
          saved = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)
          saved.projpaths.should == [
            'user_added_project.xcodeproj',
            "SampleProject/SampleProject.xcodeproj",
            "Pods/Pods.xcodeproj"
          ]
        end

        it "preserves the order of the projects in the workspace" do
          projpaths = [
            "Pods/Pods.xcodeproj",
            "SampleProject/SampleProject.xcodeproj",
          ]
          workspace = Xcodeproj::Workspace.new(projpaths)
          workspace_path = @integrator.send(:workspace_path)
          workspace.save_as(workspace_path)
          @integrator.send(:create_workspace)
          saved = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)
          saved.projpaths.should == [
            "Pods/Pods.xcodeproj",
            "SampleProject/SampleProject.xcodeproj",
          ]
        end

      end

      #-----------------------------------------------------------------------#

      describe "Private Helpers" do

        it "uses the path of the workspace defined in the podfile" do
          path = "a_path"
          @podfile.workspace(path)
          workspace_path = @integrator.send(:workspace_path)
          workspace_path.to_s.should.end_with(path + ".xcworkspace")
          workspace_path.should.be.absolute
          workspace_path.class.should == Pathname
        end

        it "names the workspace after the user project if needed" do
          @integrator.send(:workspace_path).should == temporary_directory + 'SampleProject.xcworkspace'
        end

        it "raises if no workspace could be selected" do
          @integrator.expects(:user_project_paths).returns(%w[ project1 project2 ])
          e = lambda { @integrator.send(:workspace_path) }.should.raise Informative
        end

        it "returns the paths of the user projects" do
          @integrator.send(:user_project_paths).should == [ @sample_project_path ]
        end

        it "skips libraries with empty target definitions" do
          @integrator.targets.map(&:name).should == ["Pods", "Pods-empty"]
          @integrator.send(:targets_to_integrate).map(&:name).should == ['Pods']
        end

      end

      #-----------------------------------------------------------------------#

    end
  end
end
