require File.expand_path("../../../spec_helper", __FILE__)

describe Pod::Generator::Acknowledgements do
  before do
    @sandbox = temporary_sandbox
    @target_definition = mock()
    @pods = [mock()]
    @acknowledgements = Pod::Generator::Acknowledgements.new(@target_definition, @pods)
  end

  it "calls save_as on both a Plist and a Markdown generator" do
    path = @sandbox.root + "Pods-Acknowledgements.plist"
    Pod::Generator::Plist.any_instance.expects(:save_as).with(equals(path))
    Pod::Generator::Markdown.any_instance.expects(:save_as).with(equals(path))
    @acknowledgements.save_as(path)
  end

  it "returns a string for each header and footnote text method" do
    @acknowledgements.header_title.should.be.kind_of(String)
    @acknowledgements.header_text.should.be.kind_of(String)
    @acknowledgements.footnote_title.should.be.kind_of(String)
    @acknowledgements.footnote_text.should.be.kind_of(String)
  end
end
