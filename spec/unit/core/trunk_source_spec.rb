require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe TrunkSource do
    before do
      @path = fixture('spec-repos-core/trunk')
      @source = TrunkSource.new(@path)
    end

    #-------------------------------------------------------------------------#

    it 'uses the correct repo name' do
      @source.name.should == 'trunk'
    end

    it 'uses the correct repo URL' do
      @source.url.should == 'https://cdn.cocoapods.org/'
    end

    #-------------------------------------------------------------------------#
  end
end
