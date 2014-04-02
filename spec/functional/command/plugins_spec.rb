require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe "Command::Plugins" do
    extend SpecHelper::Command

    before do
      @argv = CLAide::ARGV.new([])
      @command = Command::Plugins.new(argv)
    end

    it "exists" do
      @command.should.not.be.nil?
    end

    it "has a json attribute that starts out nil" do
      @command.json.should.be.nil?
    end

    it "downloads the json file" do
      json_fixture = fixture('plugins.json')
      @command.stubs(:open).returns(File.open(json_fixture))
      @command.download_json
      @command.json.should.not.be.nil?
      @command.json.should.be.kind_of? Hash
      @command.json['plugins'].size.should.eql? 2
    end

    it "notifies the user if the download fails" do
      json_fixture = fixture('plugins.json')
      @command.stubs(:open).throws("404 File Not Found")
      @command.run
      UI.output.should.include("Could not download plugins list from cocoapods.org")
      @command.json.should.be.nil?
    end

    it "prints out each plugin" do
      json_fixture = fixture('plugins.json')
      @json = JSON.parse(File.read(json_fixture))
      @command.json = @json
      @command.run
      UI.output.should.include("github.com/CocoaPods/cocoapods-fake")
      UI.output.should.include("github.com/chneukirchen/bacon")
    end

    it "detects if a gem is installed" do
      @command.is_installed?("bacon").should.be.true
      @command.is_installed?("fake-fake-fake-gem").should.be.false
    end

  end
end
