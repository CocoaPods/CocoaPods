require File.expand_path('../../spec_helper', __FILE__)

describe Pod::LocalPod do

  # a LocalPod represents a local copy of the dependency, inside the pod root, built from a spec
  
  before do
    @sandbox = temporary_sandbox
    @pod = Pod::LocalPod.new(fixture_spec('banana-lib/BananaLib.podspec'), @sandbox)
    copy_fixture_to_pod('banana-lib', @pod)
  end
  
  it 'returns the Pod root directory path' do
    @pod.root.should == @sandbox.root + 'BananaLib'
  end
  
  it "creates it's own root directory if it doesn't exist" do
    @pod.create
    File.directory?(@pod.root).should.be.true
  end
  
  it "can execute a block within the context of it's root" do
    @pod.chdir { FileUtils.touch("foo") }
    Pathname(@pod.root + "foo").should.exist
  end
  
  it 'can delete itself' do
    @pod.create
    @pod.implode
    @pod.root.should.not.exist
  end
  
  it 'returns an expanded list of source files, relative to the sandbox root' do
    @pod.source_files.sort.should == [
      Pathname.new("BananaLib/Classes/Banana.m"), 
      Pathname.new("BananaLib/Classes/Banana.h")
    ].sort
  end
  
  it 'returns an expanded list of absolute clean paths' do
    @pod.clean_paths.should == [@sandbox.root + "BananaLib/sub-dir"]
  end
  
  it 'returns an expanded list of resources, relative to the sandbox root' do
    @pod.resources.should == [Pathname.new("BananaLib/Resources/logo-sidebar.png")]
  end
  
  it 'returns a list of header files' do
    @pod.header_files.should == [Pathname.new("BananaLib/Classes/Banana.h")]
  end
  
  it 'can clean up after itself' do
    @pod.clean_paths.tap do |paths|
      @pod.clean
      
      paths.each do |path|
        path.should.not.exist
      end
    end
  end
  
  it "can link it's headers into the sandbox" do
    @pod.link_headers
    expected_header_path = @sandbox.headers_root + "BananaLib/Banana.h"
    expected_header_path.should.be.symlink
    File.read(expected_header_path).should == (@sandbox.root + @pod.header_files[0]).read
  end
  
  it "can add it's source files to an Xcode project target" do
    target = mock('target')
    target.expects(:add_source_file).with(Pathname.new("BananaLib/Classes/Banana.m"), anything, anything)
    @pod.add_to_target(target)
  end
  
  it "can add it's source files to a target with any specially configured compiler flags" do
    @pod.specification.compiler_flags = '-d some_flag'
    target = mock('target')
    target.expects(:add_source_file).with(anything, anything, "-d some_flag")
    @pod.add_to_target(target)
  end
  
end
