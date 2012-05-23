require File.expand_path('../../spec_helper', __FILE__)

def stub_pod_with_source(source_options)
  specification = stub(
    :source => source_options
  )
  stub('pod') do
    stubs(:root).returns(temporary_sandbox.root)
    stubs(:top_specification).returns(specification)
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

  it 'returns a github downloader when the :git URL is on github' do
    pod = Pod::LocalPod.new(fixture_spec('banana-lib/BananaLib.podspec'), temporary_sandbox, Pod::Platform.ios)
    pod.top_specification.stubs(:source).returns(:git => "git://github.com/CocoaPods/CocoaPods")
    downloader = Pod::Downloader.for_pod(pod)
    downloader.should.be.instance_of Pod::Downloader::GitHub
  end
end

describe Pod::Downloader::GitHub do

  it 'can convert public HTTP repository URLs to the tarball URL' do
    downloader = Pod::Downloader.for_pod(stub_pod_with_source(
      :git => "https://github.com/CocoaPods/CocoaPods.git"
    ))
    downloader.tarball_url_for('master').should == "https://github.com/CocoaPods/CocoaPods/tarball/master"
  end

  it 'can convert private HTTP repository URLs to the tarball URL' do
    downloader = Pod::Downloader.for_pod(stub_pod_with_source(
      :git => "https://lukeredpath@github.com/CocoaPods/CocoaPods.git"
    ))
    downloader.tarball_url_for('master').should == "https://github.com/CocoaPods/CocoaPods/tarball/master"
  end

  it 'can convert private SSH repository URLs to the tarball URL' do
    downloader = Pod::Downloader.for_pod(stub_pod_with_source(
      :git => "git@github.com:CocoaPods/CocoaPods.git"
    ))
    downloader.tarball_url_for('master').should == "https://github.com/CocoaPods/CocoaPods/tarball/master"
  end

  it 'can convert public git protocol repository URLs to the tarball URL' do
    downloader = Pod::Downloader.for_pod(stub_pod_with_source(
      :git => "git://github.com/CocoaPods/CocoaPods.git"
    ))
    downloader.tarball_url_for('master').should == "https://github.com/CocoaPods/CocoaPods/tarball/master"
  end

end
