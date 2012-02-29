require File.expand_path('../../spec_helper', __FILE__)

describe Pod::ProjectIntegration do
  
  before do
    @sample_project_path = SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
    Pod::ProjectIntegration.integrate_with_project(@sample_project_path)
    @sample_project = Xcodeproj::Project.new(@sample_project_path)
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
    xcconfig_file = @sample_project.files.where(:path => "Pods/Pods.xcconfig")
    
    @sample_project.targets.each do |target|
      target.buildConfigurations.each do |config|
        config.baseConfiguration.should == xcconfig_file
      end
    end
  end
  
  it 'adds a reference to the libPods static library' do
    static_lib = @sample_project.files.where(:name => "libPods.a")
    static_lib.should.not.be.nil
  end
  
  it 'adds the libPods static library to the "Link binary with libraries" build phase of each target' do
    @sample_project.targets.each do |target|
      framework_build_phase = target.frameworks_build_phases.first
      framework_build_phase.files.where(:file => {:name => 'libPods.a'}).should.not.be.nil
    end
  end
  
  it 'adds a Copy Pods Resources build phase to each target' do
    @sample_project.targets.each do |target|
      expected_phase = target.shell_script_build_phases.where(:name => "Copy Pods Resources")
      expected_phase.shellScript.strip.should == "\"${SRCROOT}/Pods/Pods-resources.sh\"".strip
    end
  end
end

