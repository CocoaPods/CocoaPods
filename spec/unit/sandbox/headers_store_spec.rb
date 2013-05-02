require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Sandbox::HeadersStore do

    before do
      @sandbox = Pod::Sandbox.new(temporary_directory + 'Sandbox')
      @header_dir = Sandbox::HeadersStore.new(@sandbox, 'Headers')
    end

    it "returns it's headers root" do
      @header_dir.root.should == temporary_directory + 'Sandbox/Headers'
    end

    it "can add namespaced headers to it's header path using symlinks and return the relative path" do
      FileUtils.mkdir_p(@sandbox.root + "ExampleLib/")
      namespace_path = Pathname.new("ExampleLib")
      relative_header_paths = [
        Pathname.new("ExampleLib/MyHeader.h"),
        Pathname.new("ExampleLib/MyOtherHeader.h")
      ]
      relative_header_paths.each do |path|
        File.open(@sandbox.root + path, "w") { |file| file.write('hello') }
      end
      symlink_paths = @header_dir.add_files(namespace_path, relative_header_paths)
      symlink_paths.each do |path|
        path.should.be.symlink
        File.read(path).should == "hello"
      end
    end

    it 'keeps a list of unique header search paths when headers are added' do
      FileUtils.mkdir_p(@sandbox.root + "ExampleLib/Dir")
      namespace_path = Pathname.new("ExampleLib")
      relative_header_paths = [
        Pathname.new("ExampleLib/Dir/MyHeader.h"),
        Pathname.new("ExampleLib/Dir/MyOtherHeader.h")
      ]
      relative_header_paths.each do |path|
        File.open(@sandbox.root + path, "w") { |file| file.write('hello') }
      end
      @header_dir.add_files(namespace_path, relative_header_paths)
      @header_dir.search_paths.should.include("${PODS_ROOT}/Headers/ExampleLib")
    end

    it 'always adds the Headers root to the header search paths' do
      @header_dir.search_paths.should.include("${PODS_ROOT}/Headers")
    end
  end
end
