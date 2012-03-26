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
    def command.puts(msg = '')
      (@printed ||= '') << "#{msg}\n"
    end
    command
  end

  it "it accepts corret inputs and runs without errors" do
    lambda { command().run }.should.not.raise
    lambda { command(argv('10')).run }.should.not.raise
  end

  it "complains if the days parameter is not a number" do
    lambda { command(argv('10a')).run }.should.raise Pod::Command::Help
  end


  it "returns the specs know in a given commit" do
    specs = command(argv('10')).spec_names_from_commit('cad98852103394951850f89f0efde08f9dc41830')
    specs[00].should == 'A2DynamicDelegate'
    specs[10].should == 'DCTTextFieldValidator'
    specs[20].should == 'INKeychainAccess'
    specs[30].should == 'MKNetworkKit'
  end

  it "returns the new specs introduced after a given commit" do
    new_specs = command(argv('10')).new_specs_set('1c138d254bd39a3ccbe95a720098e2aaad5c5fc1')
    new_specs[0].name.should == 'iCarousel'
    new_specs[1].name.should == 'libPusher'
  end
end


