require File.expand_path("../../../spec_helper", __FILE__)

describe Pod::Generator::Acknowledgements do
  before do
    @sandbox = temporary_sandbox
    @target_definition = mock
    @pods = [mock]
    @acknowledgements = Pod::Generator::Acknowledgements.new(@target_definition, @pods)
  end

  it "the the generators" do
    generators = Pod::Generator::Acknowledgements.generators
    generators.map { |g| g.name.split('::').last }.should == ['Plist', 'Markdown']
  end

  it "returns a string for each header and footnote text method" do
    @acknowledgements.header_title.should.be.kind_of(String)
    @acknowledgements.header_text.should.be.kind_of(String)
    @acknowledgements.footnote_title.should.be.kind_of(String)
    @acknowledgements.footnote_text.should.be.kind_of(String)
  end
end
