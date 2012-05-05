require File.expand_path("../../../spec_helper", __FILE__)

describe Pod::Generator::Acknowledgements do
  before do
    @podfile = Pod::Podfile.new do
      platform :ios
      xcodeproj "dummy"
    end
    @target_definition = @podfile.target_definitions[:default]

    @sandbox = temporary_sandbox
    @pods = [Pod::LocalPod.new(fixture_spec("banana-lib/BananaLib.podspec"), @sandbox, Pod::Platform.ios)]
    copy_fixture_to_pod("banana-lib", @pods[0])
    @acknowledgements = Pod::Generator::Acknowledgements.new(@target_definition, @pods)
  end

  it "calls save_as on both a Plist and a Markdown generator" do
    Pod::Generator::Plist.any_instance.expects(:save_as)
    Pod::Generator::Markdown.any_instance.expects(:save_as)
    path = @sandbox.root + "#{@target_definition.label}-Acknowledgements.plist"
    @acknowledgements.save_as(path)
  end

  it "returns a string for each header and footnote text method" do
    @acknowledgements.header_title.should.be.kind_of(String)
    @acknowledgements.header_text.should.be.kind_of(String)
    @acknowledgements.footnote_title.should.be.kind_of(String)
    @acknowledgements.footnote_text.should.be.kind_of(String)
  end
end
