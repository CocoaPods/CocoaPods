require File.expand_path('../../../spec_helper', __FILE__)

module Pod

  describe Command::Project do

    it "tells the user that no Podfile or podspec was found in the current working dir" do
      Command::Install.new(CLAide::ARGV.new(['--no-repo-update']))
      config.skip_repo_update.should.be.true
    end

  end

  #---------------------------------------------------------------------------#

  describe Command::Install do

    it "tells the user that no Podfile or podspec was found in the current working dir" do
      exception = lambda { run_command('install', '--no-repo-update') }.should.raise Informative
      exception.message.should.include "No `Podfile' found in the current working directory."
    end

  end

  #---------------------------------------------------------------------------#

  describe Command::Update do
    extend SpecHelper::TemporaryRepos

    it "tells the user that no Podfile was found in the current working dir" do
      exception = lambda { run_command('update','--no-repo-update') }.should.raise Informative
      exception.message.should.include "No `Podfile' found in the current working directory."
    end

    it "tells the user that no Lockfile was found in the current working dir" do
      file = temporary_directory + 'Podfile'
      File.open(file, 'w') do |f|
        f.puts('platform :ios')
        f.puts('pod "Reachability"')
      end
      Dir.chdir(temporary_directory) do
        exception = lambda { run_command('update', 'Reachability', '--no-repo-update') }.should.raise Informative
        exception.message.should.include "No `Podfile.lock' found in the current working directory"
      end
    end

  end

  #---------------------------------------------------------------------------#

end

