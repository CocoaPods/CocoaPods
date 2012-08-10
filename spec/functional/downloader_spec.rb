require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe "Downloader" do
    before do
      @pod = LocalPod.new(fixture_spec('banana-lib/BananaLib.podspec'), temporary_sandbox, Platform.ios)
    end

    describe "for Mercurial" do
      it "check's out a specific revision" do
        @pod.top_specification.stubs(:source).returns(
          :hg => fixture('mercurial-repo'), :revision => '46198bb3af96'
        )
        downloader = Downloader.for_pod(@pod)
        downloader.download
        (@pod.root + 'README').read.strip.should == 'first commit'
      end

      it "raises if it fails to download" do
        @pod.top_specification.stubs(:source).returns(
          :hg => "find me if you can", :revision => '46198bb3af96'
        )
        downloader = Downloader.for_pod(@pod)
        lambda { downloader.download }.should.raise Informative
      end
    end

    describe "for Subversion" do

      it "check's out a specific revision" do
        @pod.top_specification.stubs(:source).returns(
          :svn => "file://#{fixture('subversion-repo')}", :revision => '1'
        )
        downloader = Downloader.for_pod(@pod)
        downloader.download
        (@pod.root + 'README').read.strip.should == 'first commit'
      end

      it "check's out a specific tag" do
        @pod.top_specification.stubs(:source).returns(
          :svn => "file://#{fixture('subversion-repo')}", :tag => 'tag-1'
        )
        downloader = Downloader.for_pod(@pod)
        downloader.download
        (@pod.root + 'README').read.strip.should == 'tag 1'
      end

      it "check's out the head version" do
        @pod.top_specification.stubs(:source).returns(
          :svn => "file://#{fixture('subversion-repo')}", :revision => '1'
        )
        downloader = Downloader.for_pod(@pod)
        downloader.download_head
        (@pod.root + 'README').read.strip.should == 'unintersting'
      end

      it "raises if it fails to download" do
        @pod.top_specification.stubs(:source).returns(
          :svn => "find me if you can", :revision => '1'
        )
        downloader = Downloader.for_pod(@pod)
        lambda { downloader.download }.should.raise Informative
      end
    end


    describe "for HTTP" do
      extend SpecHelper::TemporaryDirectory

      it "download file and unzip it" do
        @pod.top_specification.stubs(:source).returns(
          :http => 'http://dl.google.com/googleadmobadssdk/googleadmobsearchadssdkios.zip'
        )
        downloader = Downloader.for_pod(@pod)
        VCR.use_cassette('tarballs', :record => :new_episodes) { downloader.download }

        (@pod.root + 'GoogleAdMobSearchAdsSDK/GADSearchRequest.h').should.exist
        (@pod.root + 'GoogleAdMobSearchAdsSDK/GADSearchRequest.h').read.strip.should =~ /Google Search Ads iOS SDK/
      end

      it "raises if it fails to download" do
        @pod.top_specification.stubs(:source).returns(
          :http => 'find me if you can.zip'
        )
        downloader = Downloader.for_pod(@pod)
        lambda { downloader.download }.should.raise Informative
      end
    end
  end
end
