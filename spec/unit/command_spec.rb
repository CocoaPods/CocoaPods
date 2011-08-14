require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Command" do
  it "returns the proper command class" do
    Pod::Command.parse("help").should.be.instance_of Pod::Command::Help
    Pod::Command.parse("setup").should.be.instance_of Pod::Command::Setup
    Pod::Command.parse("spec").should.be.instance_of Pod::Command::Spec
    Pod::Command.parse("repo").should.be.instance_of Pod::Command::Repo
  end
end
