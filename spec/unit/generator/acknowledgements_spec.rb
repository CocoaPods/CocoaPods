require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Generator::Acknowledgements do
    before do
      @file_accessor = fixture_file_accessor('banana-lib/BananaLib.podspec')
      @spec = @file_accessor.spec
      @generator = Pod::Generator::Acknowledgements.new([@file_accessor])
    end

    describe 'In general' do
      it 'returns the classes of the concrete generators generators' do
        generators = Pod::Generator::Acknowledgements.generators
        generators.map { |g| g.name.split('::').last }.should == %w(Plist Markdown)
      end

      it 'returns a string for each header and footnote text method' do
        @generator.header_title.should.be.kind_of(String)
        @generator.header_text.should.be.kind_of(String)
        @generator.footnote_title.should.be.kind_of(String)
        @generator.footnote_text.should.be.kind_of(String)
      end
    end

    #-----------------------------------------------------------------------#

    describe 'Private methods' do
      it 'returns the root specifications' do
        generator = Pod::Generator::Acknowledgements.new([@file_accessor, @file_accessor])
        generator.send(:specs).should == [@file_accessor.spec]
      end

      it 'returns the license' do
        text_from_spec = @generator.send(:license_text, @spec)
        text_from_spec.should == 'Permission is hereby granted ...'
      end

      it 'returns the license from the file' do
        @spec.stubs(:license).returns(:type => 'MIT', :file => 'README')
        text_from_spec = @generator.send(:license_text, @spec)
        text_from_spec.should == "post v1.0\n"
      end

      it "warns the user if the file specified in the license doesn't exists" do
        @spec.stubs(:license).returns(:type => 'MIT', :file => 'MISSING')
        @generator.send(:license_text, @spec)
        UI.warnings.should.include 'Unable to read the license file'
      end
    end

    #-----------------------------------------------------------------------#
  end
end
