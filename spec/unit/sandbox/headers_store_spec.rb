require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Sandbox::HeadersStore do
    before do
      @sandbox = Pod::Sandbox.new(temporary_directory + 'Sandbox')
      @header_dir = Sandbox::HeadersStore.new(@sandbox, 'Public')
    end

    it "returns it's headers root" do
      @header_dir.root.should == temporary_directory + 'Sandbox/Headers/Public'
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
      symlink_paths = @header_dir.add_files(namespace_path, relative_header_paths)
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
      @header_dir.add_files(namespace_path, relative_header_paths)
      @header_dir.search_paths(fake_platform).should.not.include('${PODS_ROOT}/Headers/Public/ExampleLib')
    end

    it 'only exposes header search paths for the given platform' do
      @header_dir.add_search_path('iOS Search Path', Platform.ios)
      @header_dir.add_search_path('OS X Search Path', Platform.osx)
      @header_dir.search_paths(Platform.ios).sort.should == [
        '${PODS_ROOT}/Headers/Public/iOS Search Path',
      ]
    end

    it 'returns the correct header search paths given platform and target' do
      ios_target = stub('ios-target', :name => 'ios-target')
      osx_target = stub('osx-target', :name => 'osx-target')
      @header_dir.add_search_path('ios-target', Platform.ios)
      @header_dir.add_search_path('osx-target', Platform.osx)
      @header_dir.search_paths(Platform.ios, ios_target).sort.should == [
        '${PODS_ROOT}/Headers/Public/ios-target',
      ]
      @header_dir.search_paths(Platform.osx, osx_target).sort.should == [
        '${PODS_ROOT}/Headers/Public/osx-target',
      ]
    end
  end
end
