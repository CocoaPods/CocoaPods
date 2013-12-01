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

  describe Command::Lib::Lint do
    it "lints the current working directory" do
        Dir.chdir(fixture('integration/Reachability')) do
          cmd = command('lib', 'lint', '--only-errors')
          cmd.run
          UI.output.should.include "passed validation"
        end
    end

    it "lints a single spec in the current working directory" do
        Dir.chdir(fixture('integration/Reachability')) do
          cmd = command('lib', 'lint', 'Reachability.podspec', '--quick', '--only-errors')
          cmd.run
          UI.output.should.include "passed validation"
        end
    end
  end
end

