require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Downloader" do
  it "returns a git downloader" do
    downloader = Pod::Downloader.for_source(
      '/path/to/pod_root',
      :git => 'http://example.local/banana.git', :tag => 'v1.0',
    )
    downloader.should.be.instance_of Pod::Downloader::Git
    downloader.pod_root.should == '/path/to/pod_root'
    downloader.url.should == 'http://example.local/banana.git'
    downloader.options.should == { :tag => 'v1.0' }
  end
end
