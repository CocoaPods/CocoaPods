require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Command do
    extend SpecHelper::Command

    it "displays the current version number with the --version flag" do
      lambda { Pod::Command.run(['--version']) }.should.raise SystemExit
      UI.output.should.include VERSION
    end

    it "reports the location of the AFNetworking spec" do
      lambda { Pod::Command.run(['spec', 'which', 'AFNetworking']) }.should.not.raise
      UI.output.should.include 'spec/fixtures/spec-repos/master/AFNetworking'
    end

    it "displays all news items from the blog" do
      feed_xml = File.read('spec/fixtures/important.xml')
      feed = Feedjira::Feed.parse(feed_xml)
      Feedjira::Feed.stubs(:fetch_and_parse).returns(feed)

      Pod::Command.run(['spec', 'which', 'AFNetworking'])
      UI.warnings.should.include "BREAKING: CocoaPods is awesome!!!"
      UI.warnings.should.include "We broke everything"
    end

  end
end
