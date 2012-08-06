require File.expand_path('../../spec_helper', __FILE__)
require 'tmpdir'

TMP_POD_ROOT = ROOT + "tmp" + "podroot" unless defined? TMP_POD_ROOT

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
    @sandbox.build_headers.root.should == Pathname.new(File.join(TMP_POD_ROOT, "BuildHeaders"))
  end

  it "returns it's public headers root" do
    @sandbox.public_headers.root.should == Pathname.new(File.join(TMP_POD_ROOT, "Headers"))
  end

  it "can add namespaced headers to it's header path using symlinks and return the relative path" do
    FileUtils.mkdir_p(@sandbox.root + "ExampleLib/BuildHeaders")
    namespace_path = Pathname.new("ExampleLib")
    relative_header_path = Pathname.new("ExampleLib/BuildHeaders/MyHeader.h")
    File.open(@sandbox.root + relative_header_path, "w") { |file| file.write('hello') }
    symlink_path = @sandbox.build_headers.add_file(namespace_path, relative_header_path)
    symlink_path.should.be.symlink
    File.read(symlink_path).should == 'hello'
  end

  it 'can add multiple headers at once and return the relative symlink paths' do
    FileUtils.mkdir_p(@sandbox.root + "ExampleLib/BuildHeaders")
    namespace_path = Pathname.new("ExampleLib")
    relative_header_paths = [
      Pathname.new("ExampleLib/BuildHeaders/MyHeader.h"),
      Pathname.new("ExampleLib/BuildHeaders/MyOtherHeader.h")
    ]
    relative_header_paths.each do |path|
      File.open(@sandbox.root + path, "w") { |file| file.write('hello') }
    end
    symlink_paths = @sandbox.build_headers.add_files(namespace_path, relative_header_paths)
    symlink_paths.each do |path|
      path.should.be.symlink
      File.read(path).should == "hello"
    end
  end

  it 'keeps a list of unique header search paths when headers are added' do
    FileUtils.mkdir_p(@sandbox.root + "ExampleLib/BuildHeaders")
    namespace_path = Pathname.new("ExampleLib")
    relative_header_paths = [
      Pathname.new("ExampleLib/BuildHeaders/MyHeader.h"),
      Pathname.new("ExampleLib/BuildHeaders/MyOtherHeader.h")
    ]
    relative_header_paths.each do |path|
      File.open(@sandbox.root + path, "w") { |file| file.write('hello') }
    end
    @sandbox.build_headers.add_files(namespace_path, relative_header_paths)
    @sandbox.build_headers.search_paths.should.include("${PODS_ROOT}/BuildHeaders/ExampleLib")
  end

  it 'always adds the Headers root to the header search paths' do
    @sandbox.build_headers.search_paths.should.include("${PODS_ROOT}/BuildHeaders")
  end

  it 'clears out its headers root when preparing for install' do
    @sandbox.prepare_for_install
    @sandbox.build_headers.root.should.not.exist
  end

  it "returns the path to a spec file in the root of the pod's dir" do
    FileUtils.cp_r(fixture('banana-lib'), @sandbox.root + 'BananaLib')
    @sandbox.podspec_for_name('BananaLib').should == @sandbox.root + 'BananaLib/BananaLib.podspec'
  end

  it "returns the path to a spec file in the 'Local Podspecs' dir" do
    (@sandbox.root + 'Local Podspecs').mkdir
    FileUtils.cp(fixture('banana-lib') + 'BananaLib.podspec', @sandbox.root + 'Local Podspecs')
    @sandbox.podspec_for_name('BananaLib').should == @sandbox.root + 'Local Podspecs/BananaLib.podspec'
  end

  it "returns a LocalPod for a spec file in the sandbox" do
    FileUtils.cp_r(fixture('banana-lib'), @sandbox.root + 'BananaLib')
    pod = @sandbox.installed_pod_named('BananaLib', Pod::Platform.ios)
    pod.should.be.instance_of Pod::LocalPod
    pod.top_specification.name.should == 'BananaLib'
  end

  it "returns a LocalPod for a spec instance which source is expected to be in the sandbox" do
    spec = Pod::Specification.from_file(fixture('banana-lib') + 'BananaLib.podspec')
    pod = @sandbox.local_pod_for_spec(spec, Pod::Platform.ios)
    pod.should.be.instance_of Pod::LocalPod
    pod.top_specification.name.should == 'BananaLib'
  end

  it "always returns the same cached LocalPod instance for the same spec and platform" do
    FileUtils.cp_r(fixture('banana-lib'), @sandbox.root + 'BananaLib')
    spec = Pod::Specification.from_file(@sandbox.root + 'BananaLib/BananaLib.podspec')

    pod = @sandbox.installed_pod_named('BananaLib', Pod::Platform.ios)
    @sandbox.installed_pod_named('BananaLib', Pod::Platform.ios).should.eql pod
    @sandbox.local_pod_for_spec(spec, Pod::Platform.ios).should.eql pod
  end
end
