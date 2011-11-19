require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Command" do
  it "returns the proper command class" do
    Pod::Command.parse('setup').should.be.instance_of Pod::Command::Setup
    #Pod::Command.parse('spec').should.be.instance_of Pod::Command::Spec
    Pod::Command.parse('repo', 'update').should.be.instance_of Pod::Command::Repo
  end
end

describe "Pod::Command::Setup" do
  it "complains about unknown arguments" do
    lambda { Pod::Command::Setup.new(argv('something')) }.should.raise Pod::Command::Help
  end

  it "returns the URL of the `master' spec-repo" do
    command = Pod::Command::Setup.new(argv)
    command.master_repo_url.should == 'git://github.com/CocoaPods/Specs.git'
  end
end

describe "Pod::Command::Repo" do
  it "complains about unknown arguments" do
    lambda { Pod::Command::Repo.new(argv('something')) }.should.raise Pod::Command::Help
  end
end

describe "Pod::Command::Install" do
  it "tells the user that no Podfile or podspec was found in the current working dir" do
    command = Pod::Command::Install.new(argv)
    exception = lambda {
      command.run
    }.should.raise Pod::Informative
    exception.message.should.include "No `Podfile' found in the current working directory."
  end
end
