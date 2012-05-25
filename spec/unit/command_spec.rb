require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Command" do
  it "returns the proper command class" do
    Pod::Command.parse('setup').should.be.instance_of Pod::Command::Setup
    Pod::Command.parse('spec', 'create', 'name').should.be.instance_of Pod::Command::Spec
    Pod::Command.parse('repo', 'update').should.be.instance_of Pod::Command::Repo
  end
end


describe "Pod::Command::Repo" do
  it "complains about unknown arguments" do
    lambda { Pod::Command::Repo.new(argv('something')) }.should.raise Pod::Command::Help
  end
end

