require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Installer::TargetInstaller" do
  before do
    @target_installer = Pod::Installer::TargetInstaller.new(nil, nil, nil)
    @config_before = config
    Pod::Config.instance = nil
  end

  it "should work with paths one level up" do
    config.source_root = "#{config.project_root}/subdir"
    @target_installer.pods_path_relative_to_project.to_s.should == "../Pods"
  end

  it "should work with paths at the same level" do
    @target_installer.pods_path_relative_to_project.to_s.should == "Pods"
  end

  it "should work with paths one level up" do
    config.project_root = Pathname.new("/tmp/foo")
    config.source_root = "/tmp"
    @target_installer.pods_path_relative_to_project.to_s.should == "foo/Pods"
  end

  after do
    Pod::Config.instance = @config_before
  end
end

