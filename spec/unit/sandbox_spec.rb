require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Sandbox do
    before do
      @sandbox = Pod::Sandbox.new(temporary_directory + 'Sandbox')
    end

    #-------------------------------------------------------------------------#

    describe 'In general' do
      it 'reads the real path of the root so it can be used to build relative paths' do
        root_realpath = temporary_directory + 'Folder/SubFolder'
        FileUtils.mkdir_p(root_realpath)
        symlink = temporary_directory + 'symlink'
        File.symlink(root_realpath, symlink)
        sandbox = Pod::Sandbox.new(symlink + 'Sandbox')
        sandbox.root.to_s.should.end_with 'Folder/SubFolder/Sandbox'
      end

      it "automatically creates its root if it doesn't exist" do
        File.directory?(temporary_directory + 'Sandbox').should.be.true
      end

      it 'returns the manifest' do
        @sandbox.manifest.should.nil?
      end

      it 'returns the project' do
        @sandbox.project.should.nil?
      end

      it 'returns the public headers store' do
        @sandbox.public_headers.root.should ==
          temporary_directory + 'Sandbox/Headers/Public'
      end

      it 'cleans any trace of the Pod with the given name' do
        pod_root = @sandbox.pod_dir('BananaLib')
        pod_root.mkpath
        @sandbox.specifications_root.mkpath
        @sandbox.store_podspec('BananaLib', fixture('banana-lib/BananaLib.podspec'))
        specification_path = @sandbox.specification_path('BananaLib')
        @sandbox.clean_pod('BananaLib')
        pod_root.should.not.exist
        specification_path.should.not.exist
      end

      it "doesn't remove the root of local Pods while cleaning" do
        pod_root = @sandbox.pod_dir('BananaLib')
        @sandbox.stubs(:local?).returns(true)
        pod_root.mkpath
        @sandbox.clean_pod('BananaLib')
        pod_root.should.exist
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Paths' do
      it 'returns the path of the manifest' do
        @sandbox.manifest_path.should ==
          temporary_directory + 'Sandbox/Manifest.lock'
      end

      it 'returns the path of the Pods project' do
        @sandbox.project_path.should ==
          temporary_directory + 'Sandbox/Pods.xcodeproj'
      end

      it 'returns the directory for the support files of a library' do
        @sandbox.target_support_files_dir('Pods').should ==
          temporary_directory + 'Sandbox/Target Support Files/Pods'
      end

      it 'returns the directory where a Pod is stored' do
        @sandbox.pod_dir('JSONKit').should ==
          temporary_directory + 'Sandbox/JSONKit'
      end

      it 'returns the directory where a local Pod is stored' do
        @sandbox.store_local_path('BananaLib', Pathname.new('Some Path/BananaLib.podspec'))
        @sandbox.pod_dir('BananaLib').should.be == Pathname.new('Some Path')
      end

      it 'handles symlinks in /tmp' do
        tmp_sandbox = Pod::Sandbox.new('/tmp/CocoaPods')
        tmp_sandbox.root.should.be == Pathname.new('/tmp/CocoaPods').realpath
        require 'fileutils'
        FileUtils.rm_rf(tmp_sandbox.root)
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Specification store' do
      before do
        # This is normally done in #prepare
        @sandbox.specifications_root.mkdir
      end

      it 'loads the stored specification with the given name' do
        FileUtils.cp(fixture('banana-lib/BananaLib.podspec'), @sandbox.specifications_root)
        @sandbox.specification('BananaLib').name.should == 'BananaLib'
      end

      it 'loads the stored specification from the original path' do
        spec_file = fixture('banana-lib/BananaLib.podspec')
        spec = Specification.from_file(spec_file)

        Specification.expects(:from_file).with(spec_file).once.returns(spec)

        @sandbox.store_podspec('BananaLib', spec_file)
        @sandbox.store_local_path('BananaLib', spec_file)
        @sandbox.specification('BananaLib')
      end

      it 'returns the directory where to store the specifications' do
        @sandbox.specifications_root.should ==
          temporary_directory + 'Sandbox/Local Podspecs'
      end

      it "returns the path to a spec file in the 'Local Podspecs' dir" do
        FileUtils.cp(fixture('banana-lib/BananaLib.podspec'), @sandbox.root + 'Local Podspecs')
        @sandbox.specification_path('BananaLib').should ==
          @sandbox.root + 'Local Podspecs/BananaLib.podspec'
      end

      it 'stores a podspec with a given path into the sandbox' do
        @sandbox.store_podspec('BananaLib', fixture('banana-lib/BananaLib.podspec'))
        path = @sandbox.root + 'Local Podspecs/BananaLib.podspec'
        path.should.exist
        @sandbox.specification_path('BananaLib').should == path
      end

      it 'stores a podspec with the given string into the sandbox' do
        podspec_string = fixture('banana-lib/BananaLib.podspec').read
        @sandbox.store_podspec('BananaLib', podspec_string)
        path = @sandbox.root + 'Local Podspecs/BananaLib.podspec'
        path.should.exist
        @sandbox.specification_path('BananaLib').should == path
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Pods information' do
      it 'stores the list of the names of the pre-downloaded pods' do
        @sandbox.store_pre_downloaded_pod('BananaLib')
        @sandbox.predownloaded_pods.should == ['BananaLib']
      end

      it 'returns whether a Pod has been pre-downloaded' do
        @sandbox.predownloaded_pods << 'BananaLib'
        @sandbox.predownloaded?('BananaLib').should.be.true
        @sandbox.predownloaded?('BananaLib/Subspec').should.be.true
        @sandbox.predownloaded?('Monkey').should.be.false
      end

      #--------------------------------------#

      it 'returns the checkout sources of the Pods' do
        @sandbox.store_pre_downloaded_pod('BananaLib/Subspec')
        @sandbox.predownloaded_pods.should == ['BananaLib']
      end

      it 'stores the checkout source of a Pod' do
        source = { :git => 'example.com', :commit => 'SHA' }
        @sandbox.store_checkout_source('BananaLib/Subspec', source)
        @sandbox.checkout_sources['BananaLib'].should == source
      end

      it 'returns the checkout sources of the Pods' do
        source = { :git => 'example.com', :commit => 'SHA' }
        @sandbox.store_checkout_source('BananaLib', source)
        @sandbox.checkout_sources.should == { 'BananaLib' => source }
      end

      #--------------------------------------#

      it 'stores the local path of a Pod' do
        @sandbox.store_local_path('BananaLib/Subspec', Pathname.new('Some Path/BananaLib.podspec'))
        @sandbox.development_pods['BananaLib'].should == Pathname.new('Some Path/BananaLib.podspec')
      end

      it 'returns the path of the local pods grouped by name' do
        @sandbox.store_local_path('BananaLib', 'BananaLib/BananaLib.podspec')
        @sandbox.development_pods.should == { 'BananaLib' => Pathname.new('BananaLib/BananaLib.podspec') }
      end

      it 'returns whether a Pod is local' do
        @sandbox.store_local_path('BananaLib', Pathname.new('BananaLib/BananaLib.podspec'))
        @sandbox.local?('BananaLib').should.be.true
        @sandbox.local?('BananaLib/Subspec').should.be.true
        @sandbox.local?('Monkey').should.be.false
      end
    end

    #-------------------------------------------------------------------------#
  end
end
