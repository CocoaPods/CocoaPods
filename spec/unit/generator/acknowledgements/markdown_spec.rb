require File.expand_path("../../../../spec_helper", __FILE__)

describe Pod::Generator::Markdown do
  before do
    @sandbox = temporary_sandbox
    @target_definition = mock
    @pods = [mock]
    @pods[0].expects(:license_text).returns("LICENSE_TEXT").at_least_once
    @pods[0].expects(:name).returns("POD_NAME").at_least_once
    @markdown = Pod::Generator::Markdown.new(@target_definition, @pods)
  end

  it "returns a correctly formatted title string" do
    @pods[0].unstub(:license_text)
    @pods[0].unstub(:name)
    @markdown.title_from_string("A Title").should.equal "A Title\n-------\n"
  end

  it "returns a correctly formatted license string for each pod" do
    @markdown.string_for_pod(@pods[0]).should.equal "POD_NAME\n--------\nLICENSE_TEXT\n"
  end

  it "returns a correctly formatted markdown string for the target" do
    @markdown.stubs(:header_title).returns("HEADER_TITLE")
    @markdown.stubs(:header_text).returns("HEADER_TEXT")
    @markdown.stubs(:footnote_title).returns("") # Test that extra \n isn't added for empty strings
    @markdown.stubs(:footnote_text).returns("FOOTNOTE_TEXT")
    @markdown.licenses.should.equal "HEADER_TITLE\n------------\nHEADER_TEXT\nPOD_NAME\n--------\nLICENSE_TEXT\nFOOTNOTE_TEXT\n"
  end

  it "writes a markdown file to disk" do
    given_path = @sandbox.root + "Pods-Acknowledgements"
    expected_path = @sandbox.root + "Pods-Acknowledgements.markdown"
    mockFile = mock
    mockFile.expects(:write).with(equals(@markdown.licenses))
    mockFile.expects(:close)
    File.expects(:new).with(equals(expected_path), equals("w")).returns(mockFile)
    @markdown.save_as(given_path)
  end
end
