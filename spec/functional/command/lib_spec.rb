require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::Lib do

    it "should create a new dir for the newly created pod" do
      run_command('lib', 'create', 'TestPod')
      Dir.chdir(temporary_directory) do
          Pathname.new(temporary_directory + 'TestPod').exist?.should == true
      end
    end

    it "should show link to new pod guide after creation" do
      output = run_command('lib', 'create', 'TestPod')
      output.should.include? 'http://guides.cocoapods.org/making/making-a-cocoapod'
    end

  end
end
