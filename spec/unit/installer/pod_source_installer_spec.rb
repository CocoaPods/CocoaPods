require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::PodSourceInstaller do
    FIXTURE_HEAD = Dir.chdir(SpecHelper.fixture('banana-lib')) { `git rev-parse HEAD`.chomp }

    before do
      @podfile = Podfile.new
      @spec = fixture_spec('banana-lib/BananaLib.podspec')
      @spec.source = { :git => SpecHelper.fixture('banana-lib') }
      specs_by_platform = { :ios => [@spec] }
      @installer = Installer::PodSourceInstaller.new(config.sandbox, @podfile, specs_by_platform)
    end

    #-------------------------------------------------------------------------#

    describe 'Installation' do
      describe 'Download' do
        it 'downloads the source' do
          @spec.source = { :git => SpecHelper.fixture('banana-lib'), :tag => 'v1.0' }
          @installer.install!
          pod_folder = config.sandbox.pod_dir('BananaLib')
          pod_folder.should.exist
        end

        it 'returns the checkout options of the downloader if any' do
          @spec.source = { :git => SpecHelper.fixture('banana-lib'), :branch => 'topicbranch' }
          @installer.install!
          pod_folder = config.sandbox.pod_dir('BananaLib')
          pod_folder.should.exist
        end

        it 'tries to remove stale local podspec if the source is not predownloaded, local or external' do
          config.sandbox.expects(:remove_local_podspec).with('BananaLib').once
          @installer.install!
        end

        it 'does not remove the local podspec if the source is local path' do
          @spec.source = { :path => 'BananaLib.podspec' }
          config.sandbox.store_local_path('BananaLib', 'BananaLib.podspec')
          config.sandbox.expects(:remove_local_podspec).with('BananaLib').never
          @installer.install!
        end
      end

      it 'does not show warning if the source is encrypted using https' do
        @spec.source = { :http => 'https://orta.io/sdk.zip' }
        dummy_response = Pod::Downloader::Response.new
        Downloader.stubs(:download).returns(dummy_response)
        @installer.install!
        UI.warnings.length.should.equal(0)
      end

      it 'does not show warning if the source uses file:///' do
        @spec.source = { :http => 'file:///orta.io/sdk.zip' }
        dummy_response = Pod::Downloader::Response.new
        Downloader.stubs(:download).returns(dummy_response)
        @installer.install!
        UI.warnings.length.should.equal(0)
      end

      it 'shows a warning if the source is unencrypted with http://' do
        @spec.source = { :http => 'http://orta.io/sdk.zip' }
        dummy_response = Pod::Downloader::Response.new
        Downloader.stubs(:download).returns(dummy_response)
        @installer.install!
        UI.warnings.should.include 'uses the unencrypted \'http\' protocol'
      end

      it 'does not show a warning if the source is http://localhost' do
        @spec.source = { :http => 'http://localhost:123/sdk.zip' }
        dummy_response = Pod::Downloader::Response.new
        Downloader.stubs(:download).returns(dummy_response)
        @installer.install!
        UI.warnings.length.should.equal(0)
      end

      it 'shows a warning if the source is unencrypted with git://' do
        @spec.source = { :git => 'git://git.orta.io/orta.git' }
        dummy_response = Pod::Downloader::Response.new
        Downloader.stubs(:download).returns(dummy_response)
        @installer.install!
        UI.warnings.should.include 'uses the unencrypted \'git\' protocol'
      end

      it 'does not warn for local repositories with spaces' do
        @spec.source = { :git => '/Users/kylef/Projects X', :tag => '1.0' }
        dummy_response = Pod::Downloader::Response.new
        Downloader.stubs(:download).returns(dummy_response)
        @installer.install!
        UI.warnings.length.should.equal(0)
      end

      it 'does not warn for SSH repositories' do
        @spec.source = { :git => 'git@bitbucket.org:kylef/test.git', :tag => '1.0' }
        dummy_response = Pod::Downloader::Response.new
        Downloader.stubs(:download).returns(dummy_response)
        @installer.install!
        UI.warnings.length.should.equal(0)
      end

      it 'does not warn for SSH repositories on Github' do
        @spec.source = { :git => 'git@github.com:kylef/test.git', :tag => '1.0' }
        dummy_response = Pod::Downloader::Response.new
        Downloader.stubs(:download).returns(dummy_response)
        @installer.install!
        UI.warnings.length.should.equal(0)
      end

      #--------------------------------------#

      describe 'Prepare command' do
        it 'runs the prepare command if one has been declared in the spec' do
          @spec.prepare_command = 'echo test'
          Installer::PodSourcePreparer.any_instance.expects(:bash!).once
          @installer.install!
        end

        it "doesn't run the prepare command if it hasn't been declared in the spec" do
          Installer::PodSourcePreparer.any_instance.expects(:bash!).never
          @installer.install!
        end

        it 'raises if the prepare command fails' do
          @spec.prepare_command = 'missing_command'
          should.raise Informative do
            @installer.install!
          end.message.should.match /command not found/
        end

        it 'unsets $CDPATH environment variable' do
          ENV['CDPATH'] = 'BogusPath'
          @spec.prepare_command = 'cd Classes;ls Banana.h'
          lambda { @installer.install! }.should.not.raise
        end

        it 'sets the $COCOAPODS_VERSION environment variable' do
          @spec.prepare_command = "[ \"$COCOAPODS_VERSION\" == \"#{Pod::VERSION}\" ] || exit 1"
          lambda { @installer.install! }.should.not.raise
        end

        it 'doesn\'t leak the $COCOAPODS_VERSION environment variable' do
          ENV['COCOAPODS_VERSION'] = nil
          @spec.prepare_command = 'exit 1'
          lambda { @installer.install! }.should.raise(Pod::Informative)
          ENV['COCOAPODS_VERSION'].should.be.nil
        end
      end

      #--------------------------------------#

      describe 'Cleaning' do
        it 'cleans the paths non used by the installation' do
          @installer.install!
          @installer.clean!
          unused_file = config.sandbox.root + 'BananaLib/sub-dir/sub-dir-2/somefile.txt'
          unused_file.should.not.exist
        end

        it 'preserves important files like the LICENSE and the README' do
          @installer.install!
          @installer.clean!
          readme_file = config.sandbox.root + 'BananaLib/README'
          readme_file.should.exist
        end
      end

      #--------------------------------------#

      describe 'Options' do
        it "doesn't downloads the source if the pod was already downloaded" do
          @installer.stubs(:predownloaded?).returns(true)
          @installer.expects(:download_source).never
          @installer.stubs(:clean_installation)
          @installer.install!
        end

        it "doesn't downloads the source if the pod has a local source" do
          config.sandbox.store_local_path('BananaLib', 'Some Path')
          @installer.expects(:download_source).never
          @installer.install!
        end

        it "doesn't clean the installation if the pod has a local source" do
          config.sandbox.store_local_path('BananaLib', 'Some Path')
          @installer.expects(:clean_installation).never
          @installer.install!
        end
      end

      #--------------------------------------#
    end

    #-------------------------------------------------------------------------#
  end
end
