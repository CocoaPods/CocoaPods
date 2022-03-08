require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::PodSourceDownloader do
    FIXTURE_HEAD = Dir.chdir(SpecHelper.fixture('banana-lib')) { `git rev-parse HEAD`.chomp }

    before do
      @podfile = Podfile.new
      @spec = fixture_spec('banana-lib/BananaLib.podspec')
      @spec.source = { :git => SpecHelper.fixture('banana-lib') }
      specs_by_platform = { :ios => [@spec] }
      @downloader = Installer::PodSourceDownloader.new(config.sandbox, @podfile, specs_by_platform)
    end

    #-------------------------------------------------------------------------#

    describe 'Download' do
      it 'does not show warning if the source is encrypted using https' do
        @spec.source = { :http => 'https://orta.io/sdk.zip' }
        dummy_response = Pod::Downloader::Response.new
        Downloader.stubs(:download).returns(dummy_response)
        @downloader.download!
        UI.warnings.length.should.equal(0)
      end

      it 'does not show warning if the source uses file:///' do
        @spec.source = { :http => 'file:///orta.io/sdk.zip' }
        dummy_response = Pod::Downloader::Response.new
        Downloader.stubs(:download).returns(dummy_response)
        @downloader.download!
        UI.warnings.length.should.equal(0)
      end

      it 'shows a warning if the source is unencrypted with http://' do
        @spec.source = { :http => 'http://orta.io/sdk.zip' }
        dummy_response = Pod::Downloader::Response.new
        Downloader.stubs(:download).returns(dummy_response)
        @downloader.download!
        UI.warnings.should.include 'uses the unencrypted \'http\' protocol'
      end

      it 'does not show a warning if the source is http://localhost' do
        @spec.source = { :http => 'http://localhost:123/sdk.zip' }
        dummy_response = Pod::Downloader::Response.new
        Downloader.stubs(:download).returns(dummy_response)
        @downloader.download!
        UI.warnings.length.should.equal(0)
      end

      it 'shows a warning if the source is unencrypted with git://' do
        @spec.source = { :git => 'git://git.orta.io/orta.git' }
        dummy_response = Pod::Downloader::Response.new
        Downloader.stubs(:download).returns(dummy_response)
        @downloader.download!
        UI.warnings.should.include 'uses the unencrypted \'git\' protocol'
      end

      it 'does not warn for local repositories with spaces' do
        @spec.source = { :git => '/Users/kylef/Projects X', :tag => '1.0' }
        dummy_response = Pod::Downloader::Response.new
        Downloader.stubs(:download).returns(dummy_response)
        @downloader.download!
        UI.warnings.length.should.equal(0)
      end

      it 'does not warn for SSH repositories' do
        @spec.source = { :git => 'git@bitbucket.org:kylef/test.git', :tag => '1.0' }
        dummy_response = Pod::Downloader::Response.new
        Downloader.stubs(:download).returns(dummy_response)
        @downloader.download!
        UI.warnings.length.should.equal(0)
      end

      it 'does not warn for SSH repositories on Github' do
        @spec.source = { :git => 'git@github.com:kylef/test.git', :tag => '1.0' }
        dummy_response = Pod::Downloader::Response.new
        Downloader.stubs(:download).returns(dummy_response)
        @downloader.download!
        UI.warnings.length.should.equal(0)
      end
    end
  end
end
