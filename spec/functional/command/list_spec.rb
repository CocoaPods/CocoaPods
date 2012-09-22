require File.expand_path('../../../spec_helper', __FILE__)

describe "Pod::Command::List" do
  extend SpecHelper::TemporaryRepos

  def command(arguments = argv)
    command = Pod::Command::List.new(arguments)
  end

  it "complains for wrong parameters" do
    lambda { command(argv('wrong')).run }.should.raise Pod::Command::Help
    lambda { command(argv('--wrong')).run }.should.raise Pod::Command::Help
  end

  it "presents the known pods" do
    list = command()
    list.run
    [ /ZBarSDK/,
      /TouchJSON/,
      /SDURLCache/,
      /MagicalRecord/,
      /A2DynamicDelegate/,
      /\d+ pods were found/
    ].each { |regex| Pod::UI.output.should =~ regex }
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
    ].each {|s| Pod::UI.output.should.include s }
  end
end


