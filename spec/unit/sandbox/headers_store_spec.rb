require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Sandbox::HeadersStore do
    before do
      @sandbox = Pod::Sandbox.new(temporary_directory + 'Sandbox')
      @public_header_dir = Sandbox::HeadersStore.new(@sandbox, 'Public', :public)
      @private_header_dir = Sandbox::HeadersStore.new(@sandbox, 'Private', :private)
    end

    it "returns it's headers root" do
      @public_header_dir.root.should == temporary_directory + 'Sandbox/Headers/Public'
    end

    it 'can add namespaced headers to its header path using symlinks and return the relative path' do
      FileUtils.mkdir_p(@sandbox.root + 'ExampleLib/')
      namespace_path = Pathname.new('ExampleLib')
      relative_header_paths = [
        Pathname.new('ExampleLib/MyHeader.h'),
        Pathname.new('ExampleLib/MyOtherHeader.h'),
      ]
      relative_header_paths.each do |path|
        File.open(@sandbox.root + path, 'w') { |file| file.write('hello') }
      end
      symlink_paths = @public_header_dir.add_files(namespace_path, relative_header_paths)
      symlink_paths.each do |path|
        path.should.be.symlink
        File.read(path).should == 'hello'
      end
    end

    it 'does not add recursive search paths' do
      FileUtils.mkdir_p(@sandbox.root + 'ExampleLib/Dir')
      namespace_path = Pathname.new('ExampleLib')
      relative_header_paths = [
        Pathname.new('ExampleLib/Dir/MyHeader.h'),
        Pathname.new('ExampleLib/Dir/MyOtherHeader.h'),
      ]
      relative_header_paths.each do |path|
        File.open(@sandbox.root + path, 'w') { |file| file.write('hello') }
      end
      fake_platform = mock(:name => 'fake_platform')
      @public_header_dir.add_files(namespace_path, relative_header_paths)
      @public_header_dir.search_paths(fake_platform).should.not.include('${PODS_ROOT}/Headers/Public/ExampleLib')
    end

    describe 'non modular header search paths' do
      it 'returns the correct public header search paths for the given platform' do
        @public_header_dir.add_search_path('iOS Search Path', Platform.ios)
        @public_header_dir.add_search_path('OS X Search Path', Platform.osx)
        @public_header_dir.search_paths(Platform.ios).sort.should == [
          '${PODS_ROOT}/Headers/Public',
          '${PODS_ROOT}/Headers/Public/iOS Search Path',
        ]
      end

      it 'returns the correct public header search paths given platform and target' do
        @public_header_dir.add_search_path('ios-target', Platform.ios)
        @public_header_dir.add_search_path('osx-target', Platform.osx)
        @public_header_dir.search_paths(Platform.ios, 'ios-target').sort.should == [
          '${PODS_ROOT}/Headers/Public',
          '${PODS_ROOT}/Headers/Public/ios-target',
        ]
        @public_header_dir.search_paths(Platform.osx, 'osx-target').sort.should == [
          '${PODS_ROOT}/Headers/Public',
          '${PODS_ROOT}/Headers/Public/osx-target',
        ]
      end

      it 'returns the correct private header search paths given platform and target' do
        @private_header_dir.add_search_path('ios-target', Platform.ios)
        @private_header_dir.add_search_path('osx-target', Platform.osx)
        @private_header_dir.search_paths(Platform.ios, 'ios-target', false).sort.should == [
          '${PODS_ROOT}/Headers/Private',
          '${PODS_ROOT}/Headers/Private/ios-target',
        ]
        @private_header_dir.search_paths(Platform.osx, 'osx-target', false).sort.should == [
          '${PODS_ROOT}/Headers/Private',
          '${PODS_ROOT}/Headers/Private/osx-target',
        ]
      end
    end

    describe 'modular header search paths' do
      it 'returns the correct public header search paths for the given platform' do
        @public_header_dir.add_search_path('iOS Search Path', Platform.ios)
        @public_header_dir.add_search_path('OS X Search Path', Platform.osx)
        @public_header_dir.search_paths(Platform.ios, nil, true).sort.should == [
          '${PODS_ROOT}/Headers/Public',
        ]
      end

      it 'returns the correct public header search paths given platform and target' do
        @public_header_dir.add_search_path('ios-target', Platform.ios)
        @public_header_dir.add_search_path('osx-target', Platform.osx)
        @public_header_dir.search_paths(Platform.ios, 'ios-target', true).sort.should == [
          '${PODS_ROOT}/Headers/Public',
        ]
        @public_header_dir.search_paths(Platform.osx, 'osx-target', true).sort.should == [
          '${PODS_ROOT}/Headers/Public',
        ]
      end

      it 'returns the correct private header search paths given platform and target' do
        @private_header_dir.add_search_path('ios-target', Platform.ios)
        @private_header_dir.add_search_path('osx-target', Platform.osx)
        @private_header_dir.search_paths(Platform.ios, 'ios-target', true).sort.should == [
          '${PODS_ROOT}/Headers/Private/ios-target',
        ]
        @private_header_dir.search_paths(Platform.osx, 'osx-target', true).sort.should == [
          '${PODS_ROOT}/Headers/Private/osx-target',
        ]
      end
    end
  end
end
