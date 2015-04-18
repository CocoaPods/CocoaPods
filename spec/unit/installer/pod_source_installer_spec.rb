require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::PodSourceInstaller do
    before do
      @spec = fixture_spec('banana-lib/BananaLib.podspec')
      @spec.source = { :git => SpecHelper.fixture('banana-lib') }
      specs_by_platform = { :ios => [@spec] }
      @installer = Installer::PodSourceInstaller.new(config.sandbox, specs_by_platform)
    end

    #-------------------------------------------------------------------------#

    describe 'Installation' do
      describe 'Download' do
        it 'downloads the source' do
          @spec.source = { :git => SpecHelper.fixture('banana-lib'), :tag => 'v1.0' }
          @installer.install!
          @installer.specific_source[:tag].should == 'v1.0'
          pod_folder = config.sandbox.pod_dir('BananaLib')
          pod_folder.should.exist
        end

        it 'downloads the head source even if a specific source is present specified source' do
          config.sandbox.store_head_pod('BananaLib')
          @spec.source = { :git => SpecHelper.fixture('banana-lib'), :tag => 'v1.0' }
          @installer.install!
          @installer.specific_source[:commit].should == '0b8b4084a43c38cfe308efa076fdeb3a64d9d2bc'
          pod_folder = config.sandbox.pod_dir('BananaLib')
          pod_folder.should.exist
        end

        it 'returns the checkout options of the downloader if any' do
          @spec.source = { :git => SpecHelper.fixture('banana-lib'), :branch => 'topicbranch' }
          @installer.install!
          @installer.specific_source[:commit].should == '446b22414597f1bb4062a62c4eed7af9627a3f1b'
          pod_folder = config.sandbox.pod_dir('BananaLib')
          pod_folder.should.exist
        end

        it 'stores the checkout options in the sandbox' do
          config.sandbox.store_head_pod('BananaLib')
          @spec.source = { :git => SpecHelper.fixture('banana-lib'), :tag => 'v1.0' }
          @installer.install!
          sources = @installer.sandbox.checkout_sources
          sources.should == { 'BananaLib' => {
            :git => SpecHelper.fixture('banana-lib'),
            :commit => '0b8b4084a43c38cfe308efa076fdeb3a64d9d2bc' },
          }
        end

        it 'fails when using :head for http source' do
          config.sandbox.store_head_pod('BananaLib')
          @spec.source = { :http => 'http://dl.google.com/googleadmobadssdk/googleadmobsearchadssdkios.zip' }
          @spec.source_files = 'GoogleAdMobSearchAdsSDK/*.h'
          Pod::Downloader::Http.any_instance.stubs(:download_head)
          should.raise Informative do
            @installer.install!
          end.message.should.match /does not support the :head option, as it uses a Http source./
        end
      end

      #--------------------------------------#

      describe 'Prepare command' do
        it 'runs the prepare command if one has been declared in the spec' do
          @spec.prepare_command = 'echo test'
          @installer.expects(:bash!).once
          @installer.install!
        end

        it "doesn't run the prepare command if it hasn't been declared in the spec" do
          @installer.expects(:bash!).never
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
