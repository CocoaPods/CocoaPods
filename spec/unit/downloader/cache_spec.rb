require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Downloader::Cache do
    before do
      @cache = Downloader::Cache.new(Dir.mktmpdir)
      @spec = fixture_spec('banana-lib/BananaLib.podspec')
      @spec.source = { :git => SpecHelper.fixture('banana-lib') }
      @request = Downloader::Request.new(:spec => @spec, :released => true)
      @stub_download = lambda do |cache, &blk|
        cache.define_singleton_method(:download) do |name, target, params, head|
          FileUtils.mkdir_p target
          Dir.chdir(target) { blk.call }
        end
      end
    end

    it 'returns the root' do
      @cache.root.should.be.directory?
    end

    describe 'when the download is not cached' do
      describe 'when downloading a released pod' do
        it 'downloads the source' do
          Downloader::Git.any_instance.expects(:download)
          Downloader::Git.any_instance.expects(:checkout_options).returns(@spec.source)
          response = @cache.download_pod(@request)
          response.should == Downloader::Response.new(@cache.root + @request.slug, @spec, @spec.source)
        end
      end

      describe 'when downloading an un-released pod' do
        before do
          @request = Downloader::Request.new(:name => 'BananaLib', :params => @spec.source)
          @stub_download.call @cache do
            File.open('BananaLib.podspec.json', 'w') { |f| f << @spec.to_pretty_json }
            File.open('OrangeLib.podspec.json', 'w') { |f| f << @spec.to_pretty_json.sub(/"name": "BananaLib"/, '"name": "OrangeLib"') }
            @spec.source
          end
        end

        it 'downloads the source' do
          @cache.expects(:copy_and_clean).twice
          response = @cache.download_pod(@request)
          response.should == Downloader::Response.new(@cache.root + @request.slug, @spec, @spec.source)
        end
      end
    end

    describe 'when the download is cached' do

    end

    after do
      @cache.root.rmtree
    end
  end
end
