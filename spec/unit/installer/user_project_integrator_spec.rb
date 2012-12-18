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

        @project_root = @sample_project_path.dirname
        @pods_project = Project.new()
        config.sandbox.project = @pods_project
        @libraries = @podfile.target_definitions.values.map do |target_definition|
          lib = Library.new(target_definition)
          lib.user_project_path = sample_project_path
          lib.target = @pods_project.new_target(:static_library, target_definition.label, target_definition.platform.name)
          lib.user_targets = sample_project.targets
          lib.support_files_root = config.sandbox.root
          lib.user_project = sample_project
          lib
        end
        @integrator = Installer::UserProjectIntegrator.new(@podfile, config.sandbox, @project_root, @libraries)
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
    end
  end

  #-----------------------------------------------------------------------------#

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
        @lib.user_targets = [@target]
        @lib.support_files_root = config.sandbox.root
        @lib.user_project = @sample_project
        @target_integrator = TargetIntegrator.new(@lib)
      end

      it 'returns the targets that need to be integrated' do
        @target_integrator.targets.map(&:name).should == %w[ SampleProject ]
      end

      it 'returns the targets that need to be integrated' do
        pods_library = @sample_project.frameworks_group.new_static_library('Pods')
        @target.frameworks_build_phase.add_file_reference(pods_library)
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
        @sample_project["Frameworks/libPods.a"].should.not == nil
      end

      it 'adds the libPods static library to the "Link binary with libraries" build phase of each target' do
        @target.frameworks_build_phase.files.find { |f| f.file_ref.path == 'libPods.a'}.should.not == nil
      end

      it 'adds a Copy Pods Resources build phase to each target' do
        phase = @target.shell_script_build_phases.find { |bp| bp.name == "Copy Pods Resources" }
        phase.shell_script.strip.should == "\"${SRCROOT}/../Pods/Pods-resources.sh\""
      end
    end
  end
end
