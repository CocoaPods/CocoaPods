require File.expand_path('../../../spec_helper', __FILE__)

describe "Pod::Command::Install" do
  extend SpecHelper::Command
  extend SpecHelper::TemporaryDirectory
  extend SpecHelper::TemporaryRepos

  it "should include instructions on how to reference the xcode project" do
    Pod::Command::Install.banner.should.match %r{xcodeproj 'path/to/XcodeProject'}
  end

  it "tells the user that no Podfile or podspec was found in the current working dir" do
    exception = lambda { run_command('install','--no-update') }.should.raise Pod::Informative
    exception.message.should.include "No `Podfile' found in the current working directory."
  end
end
