require File.expand_path('../../spec_helper', __FILE__)

module Pod

  describe Config do

    describe "Dependency Injection" do

      it "returns the downloader" do
        downloader = Config.downloader(Pathname.new(''), { :git => 'example.com' })
        downloader.target_path.should == Pathname.new('')
        downloader.url.should == 'example.com'
        downloader.cache_root.should == environment.cache_root
        downloader.max_cache_size.should == 500
        downloader.aggressive_cache.should.be.false
      end

      it "returns the specification statistics provider" do
        stats_provider = Config.spec_statistics_provider
        stats_provider.cache_file.should == environment.cache_root + 'statistics.yml'
      end

    end

  end
end
