require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Downloader::Cache do
    before do
      @cache = Downloader::Cache.new(Dir.mktmpdir)
      @spec = fixture_spec('banana-lib/BananaLib.podspec')
      @spec.source = { :git => SpecHelper.fixture('banana-lib') }
      @request = Downloader::Request.new(:spec => @spec, :released => true)
    end

    it 'returns the root' do
      @cache.root.should.be.directory?
    end

    describe 'when the download is not cached' do
      it 'downloads the source' do
        Downloader::Git.any_instance.expects(:download)
        Downloader::Git.any_instance.expects(:checkout_options).returns(@spec.source)
        @cache.download_pod(@request)
      end
    end

    after do
      @cache.root.rmtree
    end
  end
end
