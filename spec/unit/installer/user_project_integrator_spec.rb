require File.expand_path('../../../spec_helper', __FILE__)

describe Pod::Installer::UserProjectIntegrator do
  extend SpecHelper::TemporaryDirectory

  before do
    @podfile = Pod::Podfile.new do
      platform :ios
      dependency 'JSONKit'
      target :test_runner, :exclusive => true do
        link_with 'TestRunner'
        dependency 'Kiwi'
      end
    end

    @sample_project_path = SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
    config.project_root = @sample_project_path.dirname

    @integrator = Pod::Installer::UserProjectIntegrator.new(@sample_project_path, @podfile)
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

  it "returns a Pod::Installer::UserProjectIntegrator::Target for each target definition in the Podfile" do
    @integrator.targets.map(&:target_definition).should == @podfile.target_definitions.values
  end

  it "uses the first target in the user's project if no explicit target is specified" do
    target_integrator = @integrator.targets.first
    target_integrator.target_definition.stubs(:link_with).returns(nil)
    target_integrator.targets.should == [Xcodeproj::Project.new(@sample_project_path).targets.first]
  end
end
