require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::UserProjectIntegrator do

    describe "In general" do

      before do
        @sample_project_path = SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
        sample_project_path = @sample_project_path
        sample_project = Xcodeproj::Project.new sample_project_path

        @podfile = Podfile.new do
          platform :ios
          xcodeproj sample_project_path
          pod 'JSONKit'
          target :test_runner, :exclusive => true do
            link_with 'TestRunner'
            pod 'Kiwi'
          end
        end

        @installation_root = @sample_project_path.dirname
        @pods_project = Project.new()
        config.sandbox.project = @pods_project
        @libraries = @podfile.target_definitions.values.map do |target_definition|
          lib = Library.new(target_definition)
          lib.user_project_path = sample_project_path
          lib.target = @pods_project.new_target(:static_library, target_definition.label, target_definition.platform.name)
          lib.user_target_uuids = sample_project.targets.reject do |target|
            target.is_a? Xcodeproj::Project::Object::PBXAggregateTarget
          end.map(&:uuid)

          lib.support_files_root = config.sandbox.root
          lib.user_project_path = sample_project_path
          lib
        end
        @integrator = Installer::UserProjectIntegrator.new(@podfile, config.sandbox, @installation_root, @libraries)
      end

      it "uses the path of the workspace defined in the podfile" do
        path = "a_path"
        @podfile.workspace path
        @integrator.workspace_path.should == path + ".xcworkspace"
      end

      it "names the workspace after the user project if needed" do
        @integrator.workspace_path.should == @sample_project_path.dirname + 'SampleProject.xcworkspace'
      end

      it "raises if no workspace could be selected" do
        @integrator.expects(:user_project_paths).returns(%w[ project1 project2 ])
        lambda { @integrator.workspace_path }.should.raise Informative
      end

      it "returns the paths of the user projects" do
        @integrator.user_project_paths.should == [ @sample_project_path ]
      end

      it "adds the project being integrated to the workspace" do
        @integrator.integrate!
        workspace = Xcodeproj::Workspace.new_from_xcworkspace(@integrator.workspace_path)
        workspace.projpaths.sort.should == %w{ ../Pods/Pods.xcodeproj SampleProject.xcodeproj }
      end

      it "adds the Pods project to the workspace" do
        @integrator.integrate!
        workspace = Xcodeproj::Workspace.new_from_xcworkspace(@integrator.workspace_path)
        workspace.projpaths.find { |path| path =~ /Pods.xcodeproj/ }.should.not.be.nil
      end

      it "warns if the podfile does not contain any dependency" do
        Podfile::TargetDefinition.any_instance.stubs(:empty?).returns(true)
        @integrator.integrate!
        UI.warnings.should.include?('The Podfile does not contain any dependency')
      end

      xit "It writes the workspace only if needed" do

      end
    end
  end
end
