require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe "Command::Help" do
    extend SpecHelper::Command

    it "invokes the right command with --help flag" do
      command = command('help', 'push')
      command.should.be.instance_of Pod::Command::Push
      lambda { command.validate! }.should.raise CLAide::Help
    end

    it "raises help! if no other command is passed" do
      lambda { command('help').validate! }.should.raise CLAide::Help
    end

    it "shows the right usage" do
      Pod::Command::Help.arguments.should.equal '[COMMAND]'
    end
    
  end
end