require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::Init do

    it "runs with no parameters" do
      lambda { run_command('init') }.should.not.raise CLAide::Help
    end

    it "complains when given parameters" do
      lambda { run_command('init', 'create') }.should.raise CLAide::Help
      lambda { run_command('init', '--create') }.should.raise CLAide::Help
      lambda { run_command('init', 'NAME') }.should.raise CLAide::Help
      lambda { run_command('init', 'createa') }.should.raise CLAide::Help
      lambda { run_command('init', 'agument1', '2') }.should.raise CLAide::Help
      lambda { run_command('init', 'which') }.should.raise CLAide::Help
      lambda { run_command('init', 'cat') }.should.raise CLAide::Help
      lambda { run_command('init', 'edit') }.should.raise CLAide::Help
    end

    extend SpecHelper::TemporaryRepos

    it "creates a Podfile" do
      run_command('init')
      path = temporary_directory + 'Podfile'
      File.exists?(path).should == true
    end
  end
end
