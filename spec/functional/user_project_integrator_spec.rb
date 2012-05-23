require File.expand_path('../../spec_helper', __FILE__)

describe Pod::Installer::UserProjectIntegrator do
  extend SpecHelper::TemporaryDirectory

  before do
    config.silent = true
    @sample_project_path = SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
    config.project_root = @sample_project_path.dirname

    sample_project_path = @sample_project_path
    @podfile = Pod::Podfile.new do
      platform :ios

      xcodeproj sample_project_path, 'Test' => :debug
      link_with 'SampleProject' # this is an app target!

      dependency 'JSONKit'

      target :test_runner, :exclusive => true do
        link_with 'TestRunner'
        dependency 'Kiwi'
      end
    end

    @integrator = Pod::Installer::UserProjectIntegrator.new(@podfile)
    @integrator.integrate!

    @sample_project = Xcodeproj::Project.new(@sample_project_path)
  end

  it 'creates a workspace with a name matching the project' do
    workspace_path = @sample_project_path.dirname + "SampleProject.xcworkspace"
    workspace_path.should.exist
  end

  it 'adds the project being integrated to the workspace' do
    workspace = Xcodeproj::Workspace.new_from_xcworkspace(@sample_project_path.dirname + "SampleProject.xcworkspace")
    workspace.projpaths.sort.should == %w{ Pods/Pods.xcodeproj SampleProject.xcodeproj }
  end

  it 'adds the Pods project to the workspace' do
    workspace = Xcodeproj::Workspace.new_from_xcworkspace(@sample_project_path.dirname + "SampleProject.xcworkspace")
    workspace.projpaths.find { |path| path =~ /Pods.xcodeproj/ }.should.not.be.nil
  end

  it 'sets the Pods xcconfig as the base config for each build configuration' do
    @podfile.target_definitions.each do |_, definition|
      target = @sample_project.targets.where(:name => definition.link_with.first)
      xcconfig_file = @sample_project.files.where(:path => "Pods/#{definition.xcconfig_name}")
      target.build_configurations.each do |config|
        config.base_configuration.should == xcconfig_file
      end
    end
  end

  it 'adds references to the Pods static libraries' do
    @sample_project.files.where(:name => "libPods.a").should.not == nil
    @sample_project.files.where(:name => "libPods-test_runner.a").should.not == nil
  end

  it 'adds the libPods static library to the "Link binary with libraries" build phase of each target' do
    @podfile.target_definitions.each do |_, definition|
      target = @sample_project.targets.where(:name => definition.link_with.first)
      framework_build_phase = target.frameworks_build_phases.first
      framework_build_phase.files.where(:name => definition.lib_name).should.not == nil
    end
  end

  it 'adds a Copy Pods Resources build phase to each target' do
    @podfile.target_definitions.each do |_, definition|
      target = @sample_project.targets.where(:name => definition.link_with.first)
      phase = target.shell_script_build_phases.where(:name => "Copy Pods Resources")
      phase.shell_script.strip.should == "\"${SRCROOT}/Pods/#{definition.copy_resources_script_name}\""
    end
  end

  before do
    # Reset the cached TargetIntegrator#targets lists.
    @integrator.instance_variable_set(:@target_integrators, nil)
  end

  it "only tries to integrate Pods libraries into user targets that haven't been integrated yet" do
    app_integrator = @integrator.target_integrators.find { |t| t.target_definition.name == :default }
    test_runner_integrator = @integrator.target_integrators.find { |t| t.target_definition.name == :test_runner }

    # Remove libPods.a from the app target. But don't do it through TargetIntegrator#targets,
    # as it will return only those that still need integration.
    app_target = app_integrator.user_project.targets.where(:name => 'SampleProject')
    app_target.frameworks_build_phases.first.build_files.last.destroy

    app_integrator.expects(:add_pods_library)
    test_runner_integrator.expects(:add_pods_library).never

    @integrator.integrate!
  end

  it "does not even try to save the project if none of the target integrators had any work to do" do
    @integrator.target_integrators.first.user_project.expects(:save_as).never
    @integrator.integrate!
  end
end

