require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Command" do
  it "returns the proper command class" do
    Pod::Command.parse("help").should.be.instance_of Pod::Command::Help
    Pod::Command.parse("setup").should.be.instance_of Pod::Command::Setup
    Pod::Command.parse("spec").should.be.instance_of Pod::Command::Spec
    Pod::Command.parse("repo").should.be.instance_of Pod::Command::Repo
  end
end

describe "Pod::Command::Setup" do
  it "complains about unknown arguments" do
    lambda { Pod::Command::Setup.new('something') }.should.raise ArgumentError
  end

  before do
    @command = Pod::Command::Setup.new
  end

  it "returns the URL of the `master' spec-repo" do
    @command.master_repo_url.should == 'git://github.com/alloy/cocoa-pod-specs.git'
  end
end

describe "Pod::Command::Repo" do
  it "complains about unknown arguments" do
    lambda { Pod::Command::Repo.new('something') }.should.raise ArgumentError
  end

  it "returns the path of the spec-repo directory" do
    repo = Pod::Command::Repo.new('cd', 'private')
    repo.dir.should == File.join(config.repos_dir, 'private')
  end
end
