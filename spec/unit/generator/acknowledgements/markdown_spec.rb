require File.expand_path('../../../../spec_helper', __FILE__)

describe Pod::Generator::Markdown do
  before do
    @file_accessor = fixture_file_accessor('banana-lib/BananaLib.podspec')
    @spec = @file_accessor.spec
    @generator = Pod::Generator::Markdown.new([@file_accessor])
    @spec.stubs(:name).returns('POD_NAME')
    @generator.stubs(:license_text).returns('LICENSE_TEXT')
  end

  it 'returns a correctly formatted title string' do
    @generator.title_from_string('A Title', 2).should.equal '## A Title'
  end

  it 'returns a correctly formatted license string for each pod' do
    @generator.string_for_spec(@spec).should.equal "\n## POD_NAME\n\nLICENSE_TEXT\n"
  end

  it 'returns a correctly formatted markdown string for the target' do
    @generator.stubs(:header_title).returns('HEADER_TITLE')
    @generator.stubs(:header_text).returns('HEADER_TEXT')
    @generator.stubs(:footnote_title).returns('') # Test that extra \n isn't added for empty strings
    @generator.stubs(:footnote_text).returns('FOOTNOTE_TEXT')
    @generator.licenses.should.equal "# HEADER_TITLE\nHEADER_TEXT\n\n## POD_NAME\n\nLICENSE_TEXT\nFOOTNOTE_TEXT\n"
  end

  it 'writes a markdown file to disk' do
    basepath = config.sandbox.root + 'Pods-acknowledgements'
    given_path = @generator.class.path_from_basepath(basepath)
    expected_path = config.sandbox.root + 'Pods-acknowledgements.markdown'

    file = mock
    file.expects(:write).with(equals(@generator.licenses))
    file.expects(:close)
    File.expects(:new).with(equals(expected_path), equals('w')).returns(file)
    @generator.save_as(given_path)
  end
end
