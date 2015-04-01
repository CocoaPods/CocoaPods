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
          @installer.specific_source.should.be.nil
          pod_folder = config.sandbox.pod_dir('BananaLib')
          pod_folder.should.exist
        end

        it 'downloads the head source even if a specific source is present specified source' do
          config.sandbox.store_head_pod('BananaLib')
          @spec.source = { :git => SpecHelper.fixture('banana-lib'), :tag => 'v1.0' }
          @installer.install!
          @installer.specific_source[:commit].should == '9c7802033af588bed9dd5cb089bc8998a65bbd29'
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
            :commit => '9c7802033af588bed9dd5cb089bc8998a65bbd29' },
          }
        end

        it 'cleans up directory when an error occurs during download' do
          config.sandbox.store_head_pod('BananaLib')
          pod_folder = config.sandbox.pod_dir('BananaLib')
          partially_downloaded_file = pod_folder + 'partially_downloaded_file'

          mock_downloader = Object.new
          singleton_class = class << mock_downloader; self; end
          singleton_class.send(:define_method, :download_head) do
            FileUtils.mkdir_p(pod_folder)
            FileUtils.touch(partially_downloaded_file)
            raise('some network error')
          end
          @installer.stubs(:downloader).returns(mock_downloader)

          lambda do
            @installer.install!
          end.should.raise(RuntimeError).message.should.equal('some network error')
          partially_downloaded_file.should.not.exist
        end

        it 'fails when using :head for Http source' do
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

    describe 'Private Helpers' do
      it 'returns the clean paths' do
        @installer.send(:download_source)
        paths = @installer.send(:clean_paths)
        relative_paths = paths.map { |p| p.gsub("#{temporary_directory}/", '') }

        # Because there are thousands of files inside .git/, we're excluding
        # them from the comparison.
        paths_without_git = relative_paths.reject { |p| p.include? 'Pods/BananaLib/.git/' }

        paths_without_git.sort.should == [
          'Pods/BananaLib/.git',
          'Pods/BananaLib/.gitmodules',
          'Pods/BananaLib/BananaLib.podspec',
          'Pods/BananaLib/libPusher',
          'Pods/BananaLib/sub-dir',
          'Pods/BananaLib/sub-dir/sub-dir-2',
          'Pods/BananaLib/sub-dir/sub-dir-2/somefile.txt',
        ]
      end

      it 'returns the used files' do
        @installer.send(:download_source)
        paths = @installer.send(:used_files)
        relative_paths = paths.map { |p| p.gsub("#{temporary_directory}/", '') }
        relative_paths.sort.should == [
          'Pods/BananaLib/Bananalib.framework',
          'Pods/BananaLib/Classes/Banana.h',
          'Pods/BananaLib/Classes/Banana.m',
          'Pods/BananaLib/Classes/BananaLib.pch',
          'Pods/BananaLib/Classes/BananaPrivate.h',
          'Pods/BananaLib/Classes/BananaTrace.d',
          'Pods/BananaLib/LICENSE',
          'Pods/BananaLib/README',
          'Pods/BananaLib/Resources/logo-sidebar.png',
          'Pods/BananaLib/Resources/sub_dir',
          'Pods/BananaLib/libBananalib.a',
          'Pods/BananaLib/preserve_me.txt',
        ]
      end

      it 'handles Pods with multiple file accessors' do
        spec = fixture_spec('banana-lib/BananaLib.podspec')
        spec.source = { :git => SpecHelper.fixture('banana-lib') }
        spec.source_files = []
        spec.ios.source_files = 'Classes/*.h'
        spec.osx.source_files = 'Classes/*.m'
        ios_spec = spec.dup
        osx_spec = spec.dup
        specs_by_platform = { :ios => [ios_spec], :osx => [osx_spec] }
        @installer = Installer::PodSourceInstaller.new(config.sandbox, specs_by_platform)
        @installer.send(:download_source)
        paths = @installer.send(:used_files)
        relative_paths = paths.map { |p| p.gsub("#{temporary_directory}/", '') }
        relative_paths.sort.should == [
          'Pods/BananaLib/Bananalib.framework',
          'Pods/BananaLib/Classes/Banana.h',
          'Pods/BananaLib/Classes/Banana.m',
          'Pods/BananaLib/Classes/BananaLib.pch',
          'Pods/BananaLib/Classes/BananaPrivate.h',
          'Pods/BananaLib/LICENSE',
          'Pods/BananaLib/README',
          'Pods/BananaLib/Resources/logo-sidebar.png',
          'Pods/BananaLib/Resources/sub_dir',
          'Pods/BananaLib/libBananalib.a',
          'Pods/BananaLib/preserve_me.txt',
        ]
      end

      it 'compacts the used files as nil would be converted to the empty string' do
        Sandbox::FileAccessor.any_instance.stubs(:source_files)
        Sandbox::FileAccessor.any_instance.stubs(:vendored_libraries)
        Sandbox::FileAccessor.any_instance.stubs(:resources).returns(nil)
        Sandbox::FileAccessor.any_instance.stubs(:preserve_paths)
        Sandbox::FileAccessor.any_instance.stubs(:prefix_header)
        Sandbox::FileAccessor.any_instance.stubs(:readme)
        Sandbox::FileAccessor.any_instance.stubs(:license)
        Sandbox::FileAccessor.any_instance.stubs(:vendored_frameworks)
        paths = @installer.send(:used_files)
        paths.should == []
      end
    end

    #-------------------------------------------------------------------------#
  end
end
