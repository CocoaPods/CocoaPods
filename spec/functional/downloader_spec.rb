require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Downloader" do
  before do
    @pod = Pod::LocalPod.new(fixture_spec('banana-lib/BananaLib.podspec'), temporary_sandbox, Pod::Platform.ios)
  end

  describe "for Git" do
    extend SpecHelper::TemporaryDirectory

    it "check's out a specific commit" do
      @pod.top_specification.stubs(:source).returns(
        :git => fixture('banana-lib'), :commit => 'fd56054'
      )
      downloader = Pod::Downloader.for_pod(@pod)
      downloader.download

      (@pod.root + 'README').read.strip.should == 'first commit'
    end

    it "check's out a specific tag" do
      @pod.top_specification.stubs(:source).returns(
        :git => fixture('banana-lib'), :tag => 'v1.0'
      )
      downloader = Pod::Downloader.for_pod(@pod)
      downloader.download
      (@pod.root + 'README').read.strip.should == 'v1.0'
    end

    it "prepares the cache if it does not exits" do
      @pod.top_specification.stubs(:source).returns(
        :git => fixture('banana-lib'), :commit => 'fd56054'
      )
      downloader = Pod::Downloader.for_pod(@pod)
      downloader.cache_path.rmtree if downloader.cache_path.exist?
      downloader.expects(:create_cache).once
      downloader.stubs(:download_commit)
      downloader.download
    end

    it "removes the oldest repo if the caches is too big" do
      @pod.top_specification.stubs(:source).returns(
        :git => fixture('banana-lib'), :commit => 'fd56054'
      )
      original_chace_size = Pod::Downloader::Git::MAX_CACHE_SIZE
      Pod::Downloader::Git.__send__(:remove_const,'MAX_CACHE_SIZE')
      Pod::Downloader::Git::MAX_CACHE_SIZE = 0
      downloader = Pod::Downloader.for_pod(@pod)
      downloader.stubs(:cache_dir).returns(temporary_directory)
      downloader.download
      downloader.cache_path.should.not.exist?
      Pod::Downloader::Git.__send__(:remove_const,'MAX_CACHE_SIZE')
      Pod::Downloader::Git::MAX_CACHE_SIZE = original_chace_size
    end

    xit "raises if it can't find the url" do
      @pod.top_specification.stubs(:source).returns(
        :git => 'find_me_if_you_can'
      )
      downloader = Pod::Downloader.for_pod(@pod)
      lambda { downloader.download }.should.raise Pod::Informative
    end

    it "raises if it can't find a commit" do
      @pod.top_specification.stubs(:source).returns(
        :git => fixture('banana-lib'), :commit => 'aaaaaa'
      )
      downloader = Pod::Downloader.for_pod(@pod)
      lambda { downloader.download }.should.raise Pod::Informative
    end

    it "raises if it can't find a tag" do
      @pod.top_specification.stubs(:source).returns(
        :git => fixture('banana-lib'), :tag => 'aaaaaa'
      )
      downloader = Pod::Downloader.for_pod(@pod)
      lambda { downloader.download }.should.raise Pod::Informative
    end

    it "does not raise if it can find the reference" do
      @pod.top_specification.stubs(:source).returns(
        :git => fixture('banana-lib'), :commit => 'fd56054'
      )
      downloader = Pod::Downloader.for_pod(@pod)
      lambda { downloader.download }.should.not.raise
    end

    it "returns the cache directory as the clone url" do
      @pod.top_specification.stubs(:source).returns(
        :git => fixture('banana-lib'), :commit => 'fd56054'
      )
      downloader = Pod::Downloader.for_pod(@pod)
      downloader.clone_url.to_s.should.match /Library\/Caches\/CocoaPods\/Git/
    end

    it "updates the cache if the HEAD is requested" do
      @pod.top_specification.stubs(:source).returns(
        :git => fixture('banana-lib')
      )
      downloader = Pod::Downloader.for_pod(@pod)
      downloader.expects(:update_cache).once
      downloader.download
    end

    it "updates the cache if the ref is not available" do
      # create the origin repo and the cache
      tmp_repo_path = temporary_directory + 'banana-lib-source'
      `git clone #{fixture('banana-lib')} #{tmp_repo_path}`

      @pod.top_specification.stubs(:source).returns(
        :git => tmp_repo_path, :commit => 'fd56054'
      )
      downloader = Pod::Downloader.for_pod(@pod)
      downloader.download

      # make a new commit in the origin
      commit = ''
      Dir.chdir(tmp_repo_path) do
        `touch test.txt`
        `git add test.txt`
        `git commit -m 'test'`
        commit = `git rev-parse HEAD`.chomp
      end

      # require the new commit
      pod = Pod::LocalPod.new(fixture_spec('banana-lib/BananaLib.podspec'), temporary_sandbox, Pod::Platform.ios)
      pod.top_specification.stubs(:source).returns(
        :git => tmp_repo_path, :commit => commit
      )
      downloader = Pod::Downloader.for_pod(pod)
      downloader.download
      (pod.root + 'test.txt').should.exist?
    end

    it "doesn't updates cache the if the ref is available" do
      @pod.top_specification.stubs(:source).returns(
        :git => fixture('banana-lib'), :commit => 'fd56054'
      )
      downloader = Pod::Downloader.for_pod(@pod)
      downloader.download
      downloader.expects(:update_cache).never
      downloader.download
    end
  end

  describe "for GitHub repositories, with :download_only set to true" do
    extend SpecHelper::TemporaryDirectory

    it "downloads HEAD with no other options specified" do
      @pod.top_specification.stubs(:source).returns(
        :git => "git://github.com/lukeredpath/libPusher.git", :download_only => true
      )
      downloader = Pod::Downloader.for_pod(@pod)

      VCR.use_cassette('tarballs', :record => :new_episodes) { downloader.download }

      # deliberately keep this assertion as loose as possible for now
      (@pod.root + 'README.md').readlines[0].should =~ /libPusher/
    end

    it "downloads a specific tag when specified" do
      @pod.top_specification.stubs(:source).returns(
        :git => "git://github.com/lukeredpath/libPusher.git", :tag => 'v1.1', :download_only => true
      )
      downloader = Pod::Downloader.for_pod(@pod)

      VCR.use_cassette('tarballs', :record => :new_episodes) { downloader.download }

      # deliberately keep this assertion as loose as possible for now
      (@pod.root + 'libPusher.podspec').readlines.grep(/1.1/).should.not.be.empty
    end

    it "downloads a specific commit when specified" do
      @pod.top_specification.stubs(:source).returns(
        :git => "git://github.com/lukeredpath/libPusher.git", :commit => 'eca89998d5', :download_only => true
      )
      downloader = Pod::Downloader.for_pod(@pod)

      VCR.use_cassette('tarballs', :record => :new_episodes) { downloader.download }

      # deliberately keep this assertion as loose as possible for now
      (@pod.root + 'README.md').readlines[0].should =~ /PusherTouch/
    end
  end

  describe "for Mercurial" do
    it "check's out a specific revision" do
      @pod.top_specification.stubs(:source).returns(
        :hg => fixture('mercurial-repo'), :revision => '46198bb3af96'
      )
      downloader = Pod::Downloader.for_pod(@pod)
      downloader.download
      (@pod.root + 'README').read.strip.should == 'first commit'
    end
  end

  describe "for Subversion" do
    it "check's out a specific revision" do
      @pod.top_specification.stubs(:source).returns(
        :svn => "file://#{fixture('subversion-repo')}", :revision => '1'
      )
      downloader = Pod::Downloader.for_pod(@pod)
      downloader.download
      (@pod.root + 'README').read.strip.should == 'first commit'
    end

    it "check's out a specific tag" do
      @pod.top_specification.stubs(:source).returns(
        :svn => "file://#{fixture('subversion-repo')}/tags/tag-1"
      )
      downloader = Pod::Downloader.for_pod(@pod)
      downloader.download
      (@pod.root + 'README').read.strip.should == 'tag 1'
    end
  end

  describe "for Http" do
    extend SpecHelper::TemporaryDirectory

    it "download file and unzip it" do
      @pod.top_specification.stubs(:source).returns(
        :http => 'http://dl.google.com/googleadmobadssdk/googleadmobsearchadssdkios.zip'
      )
      downloader = Pod::Downloader.for_pod(@pod)
      VCR.use_cassette('tarballs', :record => :new_episodes) { downloader.download }

      (@pod.root + 'GoogleAdMobSearchAdsSDK/GADSearchRequest.h').should.exist
      (@pod.root + 'GoogleAdMobSearchAdsSDK/GADSearchRequest.h').read.strip.should =~ /Google Search Ads iOS SDK/
    end
  end
end
