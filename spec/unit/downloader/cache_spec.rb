require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Downloader::Cache do
    before do
      @cache = Downloader::Cache.new(Dir.mktmpdir)
      @spec = fixture_spec('banana-lib/BananaLib.podspec')
      @spec.source = { :git => SpecHelper.fixture('banana-lib') }
      @request = Downloader::Request.new(:spec => @spec, :released => true)
      @unreleased_request = Downloader::Request.new(:name => 'BananaLib', :params => @spec.source)

      @stub_download = lambda do |&blk|
        original_download_source = Downloader.method(:download_source)
        Downloader.define_singleton_method(:download_source) do |_name, target, _params, _head|
          FileUtils.mkdir_p target
          Dir.chdir(target) do
            result = blk.call
            Downloader.define_singleton_method(:download_source, original_download_source)
            result
          end
        end
      end
    end

    after do
      @cache.root.rmtree if @cache.root.directory?
    end

    it 'returns the root' do
      @cache.root.should.be.directory?
    end

    it 'implodes when the cache is from a different CocoaPods version' do
      root = Pathname(Dir.mktmpdir)
      root.+('VERSION').open('w') { |f| f << '0.0.0' }
      root.+('FILE').open('w') { |f| f << '0.0.0' }
      @cache = Downloader::Cache.new(root)
      root.+('VERSION').read.should == Pod::VERSION
      root.+('FILE').should.not.exist?
    end

    it 'groups subspecs by platform' do
      @spec = Specification.new do |s|
        s.ios.deployment_target = '6.0'
        s.osx.deployment_target = '10.7'

        s.subspec 'subspec' do |ss|
          ss.ios.deployment_target = '8.0'
        end
      end

      @cache.send(:group_subspecs_by_platform, @spec).should == {
        Platform.new(:ios, '8.0') => [@spec.subspecs.first],
        Platform.new(:ios, '6.0') => [@spec],
        Platform.new(:osx, '10.7') => [@spec],
      }
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
          @stub_download.call do
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

    describe 'when the cache is incomplete' do
      shared 'it falls back to download the pod' do
        describe 'when downloading a released pod' do
          it 'does download the source' do
            Downloader::Git.any_instance.expects(:download).never
            @cache.expects(:uncached_pod).once
            @cache.download_pod(@request)
          end
        end

        describe 'when downloading an unreleased pod' do
          it 'does download the source' do
            Downloader::Git.any_instance.expects(:download).never
            @cache.expects(:uncached_pod).once
            @cache.download_pod(@unreleased_request)
          end

          it 'does not return a location when there is no spec with the request name' do
            @stub_download.call do
              @spec.name = 'OrangeLib'
              File.open('BananaLib.podspec.json', 'w') { |f| f << @spec.to_pretty_json }
              @spec.source
            end
            result = @cache.download_pod(@unreleased_request)
            result.location.should.be.nil
            result.spec.should.be.nil
          end
        end
      end

      before do
        [@request, @unreleased_request].each do |request|
          path_for_pod = @cache.send(:path_for_pod, request)
          path_for_pod.mkpath
          Dir.chdir(path_for_pod) do
            FileUtils.mkdir_p 'Classes'
            File.open('Classes/a.m', 'w') {}
          end
        end
      end

      describe 'because the spec is missing' do
        behaves_like 'it falls back to download the pod'
      end

      describe 'because the spec is invalid' do
        before do
          [@request, @unreleased_request].each do |request|
            path_for_spec = @cache.send(:path_for_spec, request)
            path_for_spec.dirname.mkpath
            path_for_spec.open('w') { |f| f << '{' }
          end
        end

        behaves_like 'it falls back to download the pod'
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
