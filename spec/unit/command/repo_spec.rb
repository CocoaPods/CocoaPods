require File.expand_path('../../../spec_helper', __FILE__)

describe "Pod::Command::Repo" do
  extend SpecHelper::Command

  before do
    @command = command('repo', 'update')
    @command.stubs(:bin_version).returns(Gem::Version.new('0.6.0.rc1'))
  end

  it "supports a repo with a compatible minimum version" do
    versions = { 'min' => '0.5' }
    @command.class.send(:is_compatilbe, versions).should == true
  end

  it "doesn't supports a repo with a compatible minimum version" do
    versions = { 'min' => '0.7' }
    @command.class.send(:is_compatilbe, versions).should == false
  end

  it "supports a repo with a compatible maximum version" do
    versions = { 'max' => '0.7' }
    @command.class.send(:is_compatilbe, versions).should == true
  end

  it "doesn't supports a repo with a compatible maximum version" do
    versions = { 'max' => '0.5' }
    @command.class.send(:is_compatilbe, versions).should == false
  end

  it "detects if an update is available" do
    versions = { 'last' => '0.5' }
    @command.class.send(:has_update, versions).should == false
  end

  it "detects if no update is available" do
    versions = { 'last' => '0.7' }
    @command.class.send(:has_update, versions).should == true
  end
end

