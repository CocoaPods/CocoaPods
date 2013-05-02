require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::Outdated do
    extend SpecHelper::TemporaryRepos

    it "tells the user that no Podfile was found in the current working dir" do
      exception = lambda { run_command('outdated', '--no-repo-update') }.should.raise Informative
      exception.message.should.include "No `Podfile' found in the current working directory."
    end

    it "tells the user that no Lockfile was found in the current working dir" do
      file = temporary_directory + 'Podfile'
      File.open(file, 'w') {|f| f.write('platform :ios') }
      Dir.chdir(temporary_directory) do
        exception = lambda { run_command('outdated', '--no-repo-update') }.should.raise Informative
        exception.message.should.include "No `Podfile.lock' found in the current working directory"
      end
    end
  end
end

