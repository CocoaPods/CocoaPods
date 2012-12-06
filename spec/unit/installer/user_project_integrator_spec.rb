require File.expand_path('../../../spec_helper', __FILE__)

describe UserProjectIntegrator = Pod::Installer::UserProjectIntegrator do

  describe "In general" do
    extend SpecHelper::TemporaryDirectory
    before do
      @sample_project_path = SpecHelper.create_sample_app_copy_from_fixture('SampleProject')

      sample_project_path = @sample_project_path
      @podfile = Pod::Podfile.new do
        platform :ios
        xcodeproj sample_project_path
        pod 'JSONKit'
        target :test_runner, :exclusive => true do
          link_with 'TestRunner'
          pod 'Kiwi'
        end
      end

      @project_root = @sample_project_path.dirname
      @pods_project = Pod::Project.new(config.sandbox)
      @integrator   = UserProjectIntegrator.new(@podfile, @pods_project, @project_root)

      @podfile.target_definitions.values.each { |td| @pods_project.add_pod_library(td) }
    end

    it "returns the podfile" do
      @integrator.podfile.should == @podfile
    end

    it "returns the pods project" do
      @integrator.pods_project.should == @pods_project
    end

    it "returns the project root" do
      @integrator.project_root.should == @project_root
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
      lambda { @integrator.workspace_path }.should.raise Pod::Informative
    end

    it "returns the paths of the user projects" do
      @integrator.user_project_paths.should == [ @sample_project_path ]
    end
  end

  #--------------------------------------#

  describe "Integration" do
    extend SpecHelper::TemporaryDirectory

    before do
      @sample_project_path = SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
      sample_project_path = @sample_project_path
      @podfile = Pod::Podfile.new do
        platform :ios
        xcodeproj sample_project_path
        pod 'JSONKit'
      end
      @project_root = @sample_project_path.dirname
      @pods_project = Pod::Project.new(config.sandbox)
      @integrator   = UserProjectIntegrator.new(@podfile, @pods_project, @project_root)
      @podfile.target_definitions.values.each { |td| @pods_project.add_pod_library(td) }
      @integrator.integrate!
    end

    it "adds the project being integrated to the workspace" do
      workspace = Xcodeproj::Workspace.new_from_xcworkspace(@integrator.workspace_path)
      workspace.projpaths.sort.should == %w{ ../Pods/Pods.xcodeproj SampleProject.xcodeproj }
    end

    it "adds the Pods project to the workspace" do
      workspace = Xcodeproj::Workspace.new_from_xcworkspace(@integrator.workspace_path)
      workspace.projpaths.find { |path| path =~ /Pods.xcodeproj/ }.should.not.be.nil
    end

    xit "warns if the podfile does not contain any dependency" do
      Pod::UI.output.should.include?('The Podfile does not contain any dependency')
    end
  end
end

#-----------------------------------------------------------------------------#

describe TargetIntegrator = Pod::Installer::UserProjectIntegrator::TargetIntegrator do

  describe "In general" do
    before do
      @sample_project_path = SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
      sample_project_path = @sample_project_path
      @podfile = Pod::Podfile.new do
        platform :ios
        xcodeproj sample_project_path
      end
      @pods_project = Pod::Project.new(config.sandbox)
      @podfile.target_definitions.values.each { |td| @pods_project.add_pod_library(td) }
      @library = @pods_project.libraries.first
      @target_integrator = TargetIntegrator.new(@library)
    end

    it "returns the Pod library that should be integrated" do
      @target_integrator.library.should == @library
    end

    it "returns the user's project, that contains the target, from the Podfile" do
      @target_integrator.user_project.should == Xcodeproj::Project.new(@sample_project_path)
    end

  end

  #   before do
  #     sample_project_path = SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
  #     config.project_root = sample_project_path.dirname
  #     @podfile = Pod::Podfile.new do
  #       platform :ios
  #       xcodeproj sample_project_path, 'Test' => :debug
  #       link_with 'SampleProject' # this is an app target!
  #       pod 'JSONKit'
  #
  #       target :test_runner, :exclusive => true do
  #         link_with 'TestRunner'
  #         pod 'Kiwi'
  #       end
  #     end
  #     @sample_project_path = sample_project_path
  #     pods_project = Pod::Project.new(config.sandbox)
  #     @integrator = Pod::Installer::UserProjectIntegrator.new(@podfile, pods_project)
  #     @integrator.integrate!
  #     @sample_project = Xcodeproj::Project.new(sample_project_path)
  #   end
  #
  #   it 'adds references to the Pods static libraries to the Frameworks group' do
  #     @sample_project["Frameworks/libPods.a"].should.not == nil
  #     @sample_project["Frameworks/libPods-test_runner.a"].should.not == nil
  #   end
  #
  #
  #   it 'sets the Pods xcconfig as the base config for each build configuration' do
  #     @podfile.target_definitions.each do |_, definition|
  #       target = @sample_project.targets.find { |t| t.name == definition.link_with.first }
  #       xcconfig_file = @sample_project.files.find { |f| f.path == "Pods/#{definition.xcconfig_name}" }
  #       target.build_configurations.each do |config|
  #         config.base_configuration_reference.should == xcconfig_file
  #       end
  #     end
  #   end
  #
  #   it 'adds the libPods static library to the "Link binary with libraries" build phase of each target' do
  #     @podfile.target_definitions.each do |_, definition|
  #       target = @sample_project.targets.find { |t| t.name == definition.link_with.first }
  #       target.frameworks_build_phase.files.find { |f| f.file_ref.name == definition.lib_name}.should.not == nil
  #     end
  #   end
  #
  #   it 'adds a Copy Pods Resources build phase to each target' do
  #     @podfile.target_definitions.each do |_, definition|
  #       target = @sample_project.targets.find { |t| t.name == definition.link_with.first }
  #       phase = target.shell_script_build_phases.find { |bp| bp.name == "Copy Pods Resources" }
  #       phase.shell_script.strip.should == "\"${SRCROOT}/Pods/#{definition.copy_resources_script_name}\""
  #     end
  #   end
  #
  #   before do
  #     # Reset the cached TargetIntegrator#targets lists.
  #     @integrator.instance_variable_set(:@target_integrators, nil)
  #   end
  #
  #   it "only tries to integrate Pods libraries into user targets that haven't been integrated yet" do
  #     app_integrator = @integrator.target_integrators.find { |t| t.target_definition.name == :default }
  #     test_runner_integrator = @integrator.target_integrators.find { |t| t.target_definition.name == :test_runner }
  #
  #     # Remove libPods.a from the app target. But don't do it through TargetIntegrator#targets,
  #     # as it will return only those that still need integration.
  #     app_target = app_integrator.user_project.targets.find { |t| t.name == 'SampleProject' }
  #     app_target.frameworks_build_phase.files.last.remove_from_project
  #
    # # Set the name of the libPods.a PBXFileReference to `nil` to ensure the file’s basename
    # # is used instead. Not sure yet what makes it so that the name is nil in the first place.
    # test_target = test_runner_integrator.user_project.targets.find { |t| t.name == 'TestRunner' }
    # build_file = test_target.frameworks_build_phase.files.last
    # build_file.file_ref.name = nil
  #
  #     app_integrator.expects(:add_pods_library)
  #     test_runner_integrator.expects(:add_pods_library).never
  #
  #     @integrator.integrate!
  #   end
  #
  #   it "does not even try to save the project if none of the target integrators had any work to do" do
  #     @integrator.target_integrators.first.user_project.expects(:save_as).never
  #     @integrator.integrate!
  #   end
  # end
  #
end
