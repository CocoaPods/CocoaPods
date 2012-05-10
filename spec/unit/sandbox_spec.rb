require File.expand_path('../../spec_helper', __FILE__)
require 'tmpdir'

TMP_POD_ROOT = ROOT + "tmp" + "podroot"

describe Pod::Sandbox do

  before do 
    @sandbox = Pod::Sandbox.new(TMP_POD_ROOT)
  end
  
  after do
    @sandbox.implode
  end
  
  it "automatically creates the TMP_POD_ROOT if it doesn't exist" do
    File.directory?(TMP_POD_ROOT).should.be.true
  end
  
  it "deletes the entire root directory on implode" do
    @sandbox.implode
    File.directory?(TMP_POD_ROOT).should.be.false
    FileUtils.mkdir(TMP_POD_ROOT) # put it back again
  end
  
  it "returns it's headers root" do
    @sandbox.build_header_storage.root.should == Pathname.new(File.join(TMP_POD_ROOT, "Headers"))
  end
  
  it "can add namespaced headers to it's header path using symlinks and return the relative path" do
    FileUtils.mkdir_p(@sandbox.root + "ExampleLib/Headers")
    namespace_path = Pathname.new("ExampleLib")
    relative_header_path = Pathname.new("ExampleLib/Headers/MyHeader.h")
    File.open(@sandbox.root + relative_header_path, "w") { |file| file.write('hello') }
    symlink_path = @sandbox.build_header_storage.add_file(namespace_path, relative_header_path)
    symlink_path.should.be.symlink
    File.read(symlink_path).should == 'hello'
  end
  
  it 'can add multiple headers at once and return the relative symlink paths' do
    FileUtils.mkdir_p(@sandbox.root + "ExampleLib/Headers")
    namespace_path = Pathname.new("ExampleLib")
    relative_header_paths = [
      Pathname.new("ExampleLib/Headers/MyHeader.h"),
      Pathname.new("ExampleLib/Headers/MyOtherHeader.h")
    ]
    relative_header_paths.each do |path|
      File.open(@sandbox.root + path, "w") { |file| file.write('hello') }
    end
    symlink_paths = @sandbox.build_header_storage.add_files(namespace_path, relative_header_paths)
    symlink_paths.each do |path|
      path.should.be.symlink
      File.read(path).should == "hello"
    end
  end
  
  it 'keeps a list of unique header search paths when headers are added' do
    FileUtils.mkdir_p(@sandbox.root + "ExampleLib/Headers")
    namespace_path = Pathname.new("ExampleLib")
    relative_header_paths = [
      Pathname.new("ExampleLib/Headers/MyHeader.h"),
      Pathname.new("ExampleLib/Headers/MyOtherHeader.h")
    ]
    relative_header_paths.each do |path|
      File.open(@sandbox.root + path, "w") { |file| file.write('hello') }
    end
    @sandbox.build_header_storage.add_files(namespace_path, relative_header_paths)
    @sandbox.header_search_paths.should.include("${PODS_ROOT}/Headers/ExampleLib")
  end
  
  it 'always adds the Headers root to the header search paths' do
    @sandbox.header_search_paths.should.include("${PODS_ROOT}/Headers")
  end
  
  it 'clears out its headers root when preparing for install' do
    @sandbox.prepare_for_install
    @sandbox.build_header_storage.root.should.not.exist
  end
end
