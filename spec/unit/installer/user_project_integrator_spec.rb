require File.expand_path('../../../spec_helper', __FILE__)

describe Pod::Installer::UserProjectIntegrator do
  extend SpecHelper::TemporaryDirectory

  before do
    @sample_project_path = SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
    config.project_root = @sample_project_path.dirname

    sample_project_path = @sample_project_path
    @podfile = Pod::Podfile.new do
      platform :ios
      xcodeproj sample_project_path
      dependency 'JSONKit'
      target :test_runner, :exclusive => true do
        link_with 'TestRunner'
        dependency 'Kiwi'
      end
    end

    @integrator = Pod::Installer::UserProjectIntegrator.new(@podfile)
  end

  after do
    config.project_root = nil
  end

  it "returns the path to the workspace from the Podfile" do
    @integrator.workspace_path.should == config.project_root + 'SampleProject.xcworkspace'
  end

  it "raises if no workspace could be selected" do
    @podfile.stubs(:workspace)
    lambda { @integrator.workspace_path }.should.raise Pod::Informative
  end

  it "returns the path to the Pods.xcodeproj document" do
    @integrator.pods_project_path.should == config.project_root + 'Pods/Pods.xcodeproj'
  end

  it "returns a Pod::Installer::UserProjectIntegrator::Target for each target definition in the Podfile" do
    @integrator.target_integrators.map(&:target_definition).should == @podfile.target_definitions.values
  end

  before do
    @target_integrator = @integrator.target_integrators.first
  end

  it "returns the the user's project, that contains the target, from the Podfile" do
    @target_integrator.user_project_path.should == @sample_project_path
    @target_integrator.user_project.should == Xcodeproj::Project.new(@sample_project_path)
  end

  it "raises if no project could be selected" do
    @target_integrator.target_definition.user_project.stubs(:path).returns(nil)
    lambda { @target_integrator.user_project_path }.should.raise Pod::Informative
  end

  it "raises if the project path doesn't exist" do
    @target_integrator.target_definition.user_project.path.stubs(:exist?).returns(false)
    lambda { @target_integrator.user_project_path }.should.raise Pod::Informative
  end

  it "uses the first target in the user's project if no explicit target is specified" do
    @target_integrator.target_definition.stubs(:link_with).returns(nil)
    @target_integrator.targets.should == [Xcodeproj::Project.new(@sample_project_path).targets.first]
  end
end
