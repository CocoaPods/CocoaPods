require File.expand_path('../../../spec_helper', __FILE__)

require 'xcodeproj'

module Pod
  describe Command::Lib::Create do
    it "complains if wrong parameters" do
      lambda { run_command('lib', 'create') }.should.raise CLAide::Help
    end

    it "complains if pod name contains spaces" do
      lambda { run_command('lib', 'create', 'Pod Name With Spaces') }.should.raise CLAide::Help
    end
  end
end

