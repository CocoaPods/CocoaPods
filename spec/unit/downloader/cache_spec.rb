require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Downloader::Cache do
    before do
      @cache = Downloader::Cache.new(Dir.mktmpdir)
      @spec = fixture_spec('banana-lib/BananaLib.podspec')
      @spec.source = { :git => SpecHelper.fixture('banana-lib') }
      @request = Downloader::Request.new(:spec => @spec, :released => true)
      @unreleased_request = Downloader::Request.new(:name => 'BananaLib', :params => @spec.source)
      @stub_download = lambda do |cache, &blk|
        cache.define_singleton_method(:download) do |_name, target, _params, _head|
          FileUtils.mkdir_p target
          Dir.chdir(target) { blk.call }
        end
      end
    end

    after do
      @cache.root.rmtree if @cache.root.directory?
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
          @stub_download.call @cache do
            File.open('BananaLib.podspec.json', 'w') { |f| f << @spec.to_pretty_json }
            File.open('OrangeLib.podspec.json', 'w') { |f| f << @spec.to_pretty_json.sub(/"name": "BananaLib"/, '"name": "OrangeLib"') }
            @spec.source
          end
        end

        it 'downloads the source' do
          @cache.expects(:copy_and_clean).twice
          response = @cache.download_pod(@unreleased_request)
          response.should == Downloader::Response.new(@cache.root + @unreleased_request.slug, @spec, @spec.source)
        end
      end
    end

    describe 'when the download is cached' do
      before do
        [@request, @unreleased_request].each do |request|
          path_for_spec = @cache.send(:path_for_spec, request)
          path_for_spec.dirname.mkpath
          path_for_spec.open('w') { |f| f << @spec.to_pretty_json }

          path_for_pod = @cache.send(:path_for_pod, request)
          path_for_pod.mkpath
          Dir.chdir(path_for_pod) do
            FileUtils.mkdir_p 'Classes'
            File.open('Classes/a.m', 'w') {}
          end
        end
      end

      describe 'when downloading a released pod' do
        it 'does not download the source' do
          Downloader::Git.any_instance.expects(:download).never
          @cache.expects(:uncached_pod).never
          response = @cache.download_pod(@request)
          response.should == Downloader::Response.new(@cache.root + @request.slug, @spec, @spec.source)
        end
      end

      describe 'when downloading an unreleased pod' do
        it 'does not download the source' do
          Downloader::Git.any_instance.expects(:download).never
          @cache.expects(:uncached_pod).never
          response = @cache.download_pod(@unreleased_request)
          response.should == Downloader::Response.new(@cache.root + @unreleased_request.slug, @spec, @spec.source)
        end
      end
    end
  end
end
