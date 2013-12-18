require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Command do
    extend SpecHelper::Command

    it "displays the current version number with the --version flag" do
      lambda { Pod::Command.run(['--version']) }.should.raise SystemExit
      UI.output.should.include VERSION
    end

    it "reports the location of the AFNetworking spec" do
      Pod::UI.warnings = ''
      lambda { Pod::Command.run(['spec', 'which', 'AFNetworking']) }.should.not.raise
      UI.output.should.include 'spec/fixtures/spec-repos/master/AFNetworking'
    end

  end
end
