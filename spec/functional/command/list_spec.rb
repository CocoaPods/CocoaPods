require File.expand_path('../../../spec_helper', __FILE__)

describe "Pod::Command::List" do
  extend SpecHelper::Git

  before do
    config.repos_dir = fixture('spec-repos')
  end

  after do
    config.repos_dir = tmp_repos_path
  end

  def command(arguments = argv)
    command = Pod::Command::List.new(arguments)
  end

  it "runs with correct parameters" do
    lambda { command.run }.should.not.raise
    lambda { command(argv('new')).run }.should.not.raise
  end

  it "complains for wrong parameters" do
    lambda { command(argv('wrong')).run }.should.raise Pod::Command::Help
    lambda { command(argv('--wrong')).run }.should.raise Pod::Command::Help
  end

  it "presents the known pods" do
    list = command()
    list.run
    output = list.output
    output.should.include 'ZBarSDK'
    output.should.include 'TouchJSON'
    output.should.include 'SDURLCache'
    output.should.include 'MagicalRecord'
    output.should.include 'A2DynamicDelegate'
    output.should.include '75 pods were found'
  end

  it "returns the new pods" do
    Time.stubs(:now).returns(Time.mktime(2012,2,1))
    list = command(argv('new'))
    list.run
    output = list.output
    output.should.include 'iCarousel'
    output.should.include 'cocoa-oauth'
    output.should.include 'NLCoreData'
  end
end


