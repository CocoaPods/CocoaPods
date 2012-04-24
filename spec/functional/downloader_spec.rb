require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Downloader" do
  before do
    @pod = Pod::LocalPod.new(fixture_spec('banana-lib/BananaLib.podspec'), temporary_sandbox, Pod::Platform.ios)
  end

  describe "for Git" do
    extend SpecHelper::TemporaryDirectory
  
    it "check's out a specific commit" do
      @pod.specification.stubs(:source).returns(
        :git => fixture('banana-lib'), :commit => 'fd56054'
      )
      downloader = Pod::Downloader.for_pod(@pod)
      downloader.download
      
      (@pod.root + 'README').read.strip.should == 'first commit'
    end
  
    it "check's out a specific tag" do
      @pod.specification.stubs(:source).returns(
        :git => fixture('banana-lib'), :tag => 'v1.0'
      )
      downloader = Pod::Downloader.for_pod(@pod)
      downloader.download
      (@pod.root + 'README').read.strip.should == 'v1.0'
    end
  
    it "removes the .git directory when cleaning" do
      @pod.specification.stubs(:source).returns(
        :git => fixture('banana-lib')
      )
      downloader = Pod::Downloader.for_pod(@pod)
      downloader.download
      downloader.clean
      (@pod.root + '.git').should.not.exist
    end
  end
  
  describe "for Github repositories, with :download_only set to true" do
    extend SpecHelper::TemporaryDirectory
    
    it "downloads HEAD with no other options specified" do
      @pod.specification.stubs(:source).returns(
        :git => "git://github.com/lukeredpath/libPusher.git", :download_only => true
      )
      downloader = Pod::Downloader.for_pod(@pod)
      
      VCR.use_cassette('tarballs', :record => :new_episodes) { downloader.download }
      
      # deliberately keep this assertion as loose as possible for now
      (@pod.root + 'README.md').readlines[0].should =~ /libPusher/
    end
    
    it "downloads a specific tag when specified" do
      @pod.specification.stubs(:source).returns(
        :git => "git://github.com/lukeredpath/libPusher.git", :tag => 'v1.1', :download_only => true
      )
      downloader = Pod::Downloader.for_pod(@pod)

      VCR.use_cassette('tarballs', :record => :new_episodes) { downloader.download }
      
      # deliberately keep this assertion as loose as possible for now
      (@pod.root + 'libPusher.podspec').readlines.grep(/1.1/).should.not.be.empty
    end
    
    it "downloads a specific commit when specified" do
      @pod.specification.stubs(:source).returns(
        :git => "git://github.com/lukeredpath/libPusher.git", :commit => 'eca89998d5', :download_only => true
      )
      downloader = Pod::Downloader.for_pod(@pod)
      
      VCR.use_cassette('tarballs', :record => :new_episodes) { downloader.download }
      
      # deliberately keep this assertion as loose as possible for now
      (@pod.root + 'README.md').readlines[0].should =~ /PusherTouch/
    end
    
    it 'deletes the downloaded tarball after unpacking it' do
      @pod.specification.stubs(:source).returns(
        :git => "git://github.com/lukeredpath/libPusher.git", :download_only => true
      )
      downloader = Pod::Downloader.for_pod(@pod)
      
      VCR.use_cassette('tarballs', :record => :new_episodes) { downloader.download }
      
      (@pod.root + 'tarball.tar.gz').should.not.exist
    end
  end
  
  describe "for Mercurial" do
    it "check's out a specific revision" do
      @pod.specification.stubs(:source).returns(
        :hg => fixture('mercurial-repo'), :revision => '46198bb3af96'
      )
      downloader = Pod::Downloader.for_pod(@pod)
      downloader.download
      (@pod.root + 'README').read.strip.should == 'first commit'
    end
  
    it "removes the .hg directory when cleaning" do
      @pod.specification.stubs(:source).returns(
        :hg => fixture('mercurial-repo')
      )
      downloader = Pod::Downloader.for_pod(@pod)
      downloader.download
      downloader.clean
      (@pod.root + '.hg').should.not.exist
    end
  end
  
  describe "for Subversion" do
    it "check's out a specific revision" do
      @pod.specification.stubs(:source).returns(
        :svn => "file://#{fixture('subversion-repo')}", :revision => '1'
      )
      downloader = Pod::Downloader.for_pod(@pod)
      downloader.download
      (@pod.root + 'README').read.strip.should == 'first commit'
    end
  
    it "check's out a specific tag" do
      @pod.specification.stubs(:source).returns(
        :svn => "file://#{fixture('subversion-repo')}/tags/tag-1"
      )
      downloader = Pod::Downloader.for_pod(@pod)
      downloader.download
      (@pod.root + 'README').read.strip.should == 'tag 1'
    end
  
    it "removes the .svn directories when cleaning" do
      @pod.specification.stubs(:source).returns(
        :svn => "file://#{fixture('subversion-repo')}/trunk"
      )
      downloader = Pod::Downloader.for_pod(@pod)
      downloader.download
      downloader.clean
      (@pod.root + '.svn').should.not.exist
    end
  end

  describe "for Http" do
    extend SpecHelper::TemporaryDirectory

    it "download file and unzip it" do
      @pod.specification.stubs(:source).returns(
        :http => 'http://dl.google.com/googleadmobadssdk/googleadmobsearchadssdkios.zip'
      )
      downloader = Pod::Downloader.for_pod(@pod)
      VCR.use_cassette('tarballs', :record => :new_episodes) { downloader.download }

      (@pod.root + 'GoogleAdMobSearchAdsSDK/GADSearchRequest.h').should.exist
      (@pod.root + 'GoogleAdMobSearchAdsSDK/GADSearchRequest.h').read.strip.should =~ /Google Search Ads iOS SDK/
    end

    it "removes the .zip directory when cleaning" do
      @pod.specification.stubs(:source).returns(
        :http => 'http://dl.google.com/googleadmobadssdk/googleadmobsearchadssdkios.zip'
      )
      downloader = Pod::Downloader.for_pod(@pod)
      downloader.download
      downloader.clean
      (@pod.root + 'file.zip').should.not.exist
    end
  end
  

end

