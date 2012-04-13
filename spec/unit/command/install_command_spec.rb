require File.expand_path('../../../spec_helper', __FILE__)

describe "Pod::Command::Install" do
  it "should include instructions on how to reference the xcode project" do
    Pod::Command::Install.banner.should.match %r{xcodeproj 'path/to/XcodeProject'}
  end
end

