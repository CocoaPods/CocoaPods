require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Config" do
  before do
    @original_config = config
    Pod::Config.instance = nil
  end

  after do
    Pod::Config.instance = @original_config
  end

  it "returns the singleton config instance" do
    config.should.be.instance_of Pod::Config
  end

  it "returns the path to the spec-repos dir" do
    config.repos_dir.should == File.expand_path("~/.cocoa-pods")
  end
end
