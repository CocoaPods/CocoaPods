require File.expand_path('../../../spec_helper', __FILE__)

describe "Pod::Command::List" do
  extend SpecHelper::TemporaryRepos

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
    [
      /ZBarSDK/,
      /TouchJSON/,
      /SDURLCache/,
      /MagicalRecord/,
      /A2DynamicDelegate/,
      /\d+ pods were found/
    ].each { |regex| list.output.should =~ regex }
  end

  it "returns the new pods" do
    Time.stubs(:now).returns(Time.mktime(2012,2,3))
    list = command(argv('new'))
    list.run
    [ 'iCarousel',
      'libPusher',
      'SSCheckBoxView',
      'KKPasscodeLock',
      'SOCKit',
      'FileMD5Hash',
      'cocoa-oauth',
      'iRate'
    ].each {|s| list.output.should.include s }
  end
end


