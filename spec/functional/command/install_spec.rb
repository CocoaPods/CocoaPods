require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::Install do
    

    it "tells the user that no Podfile or podspec was found in the current working dir" do
      exception = lambda { run_command('install', '--no-update') }.should.raise Informative
      exception.message.should.include "No `Podfile' found in the current working directory."
    end
  end
end
