require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Downloader" do
  it "returns a git downloader with parsed options" do
    pod = Pod::LocalPod.new(fixture_spec('banana-lib/BananaLib.podspec'), temporary_sandbox)
    downloader = Pod::Downloader.for_pod(pod)
    downloader.should.be.instance_of Pod::Downloader::Git
    downloader.url.should == 'http://banana-corp.local/banana-lib.git'
    downloader.options.should == { :tag => 'v1.0' }
  end
end
