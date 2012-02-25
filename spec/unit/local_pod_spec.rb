require File.expand_path('../../spec_helper', __FILE__)

describe Pod::LocalPod do

  # a LocalPod represents a local copy of the dependency, inside the pod root, built from a spec
  
  before do
    @spec = Pod::Specification.from_file(fixture('banana-lib/BananaLib.podspec'))
    @sandbox = temporary_sandbox
    @pod = Pod::LocalPod.new(@spec, @sandbox)
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
end
