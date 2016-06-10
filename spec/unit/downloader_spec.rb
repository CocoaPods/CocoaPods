require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Downloader do
    before do
      @target_path = Pathname.new(Dir.mktmpdir)

      source = { :git => SpecHelper.fixture('banana-lib'), :branch => 'master' }
      @request = Downloader::Request.new(:name => 'BananaLib', :params => source)
    end

    after do
      @target_path.rmtree if @target_path.directory?
    end

    it 'preprocesses requests' do
      Downloader.expects(:preprocess_request).returns(@request)
      Downloader.download(@request, @target_path, :can_cache => false)
    end
  end
end
