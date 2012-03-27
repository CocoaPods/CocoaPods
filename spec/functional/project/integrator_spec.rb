require File.expand_path('../../../spec_helper', __FILE__)

describe Pod::Project::Integrator, 'TODO UNIT SPECS!' do
  extend SpecHelper::TemporaryDirectory

  before do
    @podfile = Pod::Podfile.new do
      platform :ios
      dependency 'JSONKit'
      target :test_runner, :exclusive => true, :link_with => 'TestRunner' do
        dependency 'Kiwi'
      end
    end

    @sample_project_path = SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
    config.project_root = @sample_project_path.dirname

    @integrator = Pod::Project::Integrator.new(@sample_project_path, @podfile)
  end

  after do
    config.project_root = nil
  end

  it "returns the path to the workspace in the project's root" do
    @integrator.workspace_path.should == config.project_root + 'SampleProject.xcworkspace'
  end

  it "returns the path to the Pods.xcodeproj document" do
    @integrator.pods_project_path.should == config.project_root + 'Pods/Pods.xcodeproj'
  end

  it "returns a Pod::Project::Integrator::Target for each target definition in the Podfile" do
    @integrator.targets.map(&:target_definition).should == @podfile.target_definitions.values
  end

  it "uses the first target in the user's project if no explicit target is specified" do
    target_integrator = @integrator.targets.first
    target_integrator.target_definition.stubs(:link_with).returns(nil)
    target_integrator.targets.should == [Xcodeproj::Project.new(@sample_project_path).targets.first]
  end
end

describe Pod::Project::Integrator do
  extend SpecHelper::TemporaryDirectory

  before do
    @podfile = Pod::Podfile.new do
      platform :ios

      link_with 'SampleProject' # this is an app target!
      dependency 'JSONKit'

      target :test_runner, :exclusive => true, :link_with => 'TestRunner' do
        dependency 'Kiwi'
      end
    end

    @sample_project_path = SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
    config.project_root = @sample_project_path.dirname

    @integrator = Pod::Project::Integrator.new(@sample_project_path, @podfile)
    @integrator.integrate!
    @sample_project = Xcodeproj::Project.new(@sample_project_path)
  end

  after do
    config.project_root = nil
  end

  it 'creates a workspace with a name matching the project' do
    workspace_path = @sample_project_path.dirname + "SampleProject.xcworkspace"
    workspace_path.should.exist
  end

  it 'adds the project being integrated to the workspace' do
    workspace = Xcodeproj::Workspace.new_from_xcworkspace(@sample_project_path.dirname + "SampleProject.xcworkspace")
    workspace.should.include?("SampleProject.xcodeproj")
  end
  
  it 'adds the Pods project to the workspace' do
    workspace = Xcodeproj::Workspace.new_from_xcworkspace(@sample_project_path.dirname + "SampleProject.xcworkspace")
    workspace.projpaths.find { |path| path =~ /Pods.xcodeproj/ }.should.not.be.nil
  end
  
  it 'adds the Pods xcconfig file to the project' do
    @sample_project.files.where(:path => "Pods/Pods.xcconfig").should.not.be.nil
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
      framework_build_phase.files.where(:file => { :name => definition.lib_name }).should.not == nil
    end
  end
  
  it 'adds a Copy Pods Resources build phase to each target' do
    @podfile.target_definitions.each do |_, definition|
      target = @sample_project.targets.where(:name => definition.link_with.first)
      expected_phase = target.shell_script_build_phases.where(:name => "Copy Pods Resources")
      expected_phase.shell_script.strip.should == "\"${SRCROOT}/Pods/#{definition.copy_resources_script_name}\"".strip
    end
  end
end

