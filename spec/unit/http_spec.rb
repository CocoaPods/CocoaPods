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

describe Pod::Downloader::Http do

  it 'should find download file type' do
    downloader = Pod::Downloader.for_pod(stub_pod_with_source(
      :http => 'https://testflightapp.com/media/sdk-downloads/TestFlightSDK1.0.zip'
    ))
    downloader.should.be.instance_of Pod::Downloader::Http
    downloader.type.should == :zip
    
    
    downloader = Pod::Downloader.for_pod(stub_pod_with_source(
      :http => 'https://testflightapp.com/media/sdk-downloads/TestFlightSDK1.0.tar'
    ))
    downloader.should.be.instance_of Pod::Downloader::Http
    downloader.type.should == :tar
    
    downloader = Pod::Downloader.for_pod(stub_pod_with_source(
      :http => 'https://testflightapp.com/media/sdk-downloads/TestFlightSDK1.0.tgz'
    ))
    downloader.should.be.instance_of Pod::Downloader::Http
    downloader.type.should == :tgz
    
    downloader = Pod::Downloader.for_pod(stub_pod_with_source(
      :http => 'https://testflightapp.com/media/sdk-downloads/TestFlightSDK1.0',
      :type => :zip
    ))
    downloader.should.be.instance_of Pod::Downloader::Http
    downloader.type.should == :zip
  end
  
  it 'should download file and extract it with proper type' do
    downloader = Pod::Downloader.for_pod(stub_pod_with_source(
      :http => 'https://testflightapp.com/media/sdk-downloads/TestFlightSDK1.0.zip'
    ))
    downloader.expects(:download_file).with(anything())
    downloader.expects(:extract_with_type).with(anything(), :zip).at_least_once
    downloader.download
    
    downloader = Pod::Downloader.for_pod(stub_pod_with_source(
      :http => 'https://testflightapp.com/media/sdk-downloads/TestFlightSDK1.0.tgz'
    ))
    downloader.expects(:download_file).with(anything())
    downloader.expects(:extract_with_type).with(anything(), :tgz).at_least_once
    downloader.download    
  end
end
