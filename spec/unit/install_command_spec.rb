require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Command::Install" do
  it "should include instructions on how to reference the xcode project" do
    Pod::Command::Install.banner.should.match /xcodeproj path\/to\/project.xcodeproj/
  end

  before do
    @config_before = config
    Pod::Config.instance = nil
    config.silent = true
  end

  after do
    Pod::Config.instance = @config_before
  end

  describe "When the Podfile does not specify the xcodeproject" do
    before do
      config.stubs(:rootspec).returns(Pod::Podfile.new { platform :ios; dependency 'AFNetworking'})
    end
    it "raises an informative error if the xcodproj is not specified in the podfile" do
      installer = Pod::Command::Install.new(Pod::Command::ARGV.new)
      should.raise(Pod::Informative) { installer.run }
    end
  end
end

