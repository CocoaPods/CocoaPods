require File.expand_path('../../spec_helper', __FILE__)

def stub_pod_with_source(source_options)
  specification = stub(
    :part_of_other_pod? => false,
    :source => source_options
  )
  stub('pod') do
    stubs(:root).returns(temporary_sandbox.root)
    stubs(:specification).returns(specification)
  end
end

describe "Pod::Downloader" do
  it "returns a git downloader with parsed options" do
    pod = Pod::LocalPod.new(fixture_spec('banana-lib/BananaLib.podspec'), temporary_sandbox, Pod::Platform.ios)
    downloader = Pod::Downloader.for_pod(pod)
    downloader.should.be.instance_of Pod::Downloader::Git
    downloader.url.should == 'http://banana-corp.local/banana-lib.git'
    downloader.options.should == { :tag => 'v1.0' }
  end
end
