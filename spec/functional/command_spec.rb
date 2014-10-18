require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Command do
    extend SpecHelper::Command

    it 'displays the current version number with the --version flag' do
      Pod::Command.version.should == VERSION
    end

    it 'reports the location of the AFNetworking spec' do
      lambda { Pod::Command.run(%w(spec which AFNetworking)) }.should.not.raise
      UI.output.should.include 'spec/fixtures/spec-repos/master/Specs/AFNetworking'
    end

    it "doesn't let you run as root" do
      Process.stubs(:uid).returns(0)
      lambda { Pod::Command.run(['--version']) }.should.raise CLAide::Help
    end

    it "doesn't let you run without git installed" do
      Pod::Command.expects(:`).with('git version').raises(Errno::ENOENT)
      lambda { Pod::Command.run(['--version']) }.should.raise CLAide::Help
    end

    it "doesn't let you run with git version < 1.7.5" do
      Pod::Command.expects(:`).with('git version').returns('git version 1.7.4.1 (Apple Git-50)')
      lambda { Pod::Command.run(['--version']) }.should.raise CLAide::Help
    end
  end
end
