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
      :http => 'http://www.kernel.org/pub/linux/kernel/v1.0/linux-1.0.tar.bz2'
    ))
    downloader.should.be.instance_of Pod::Downloader::Http
    downloader.type.should == :tbz

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

    downloader = Pod::Downloader.for_pod(stub_pod_with_source(
      :http => 'http://www.kernel.org/pub/linux/kernel/v1.0/linux-1.0.tar.bz2'
    ))
    downloader.expects(:download_file).with(anything())
    downloader.expects(:extract_with_type).with(anything(), :tbz).at_least_once
    downloader.download
  end

  it 'should raise error when unsupported filetype is pass' do
    downloader = Pod::Downloader.for_pod(stub_pod_with_source(
      :http => 'https://testflightapp.com/media/sdk-downloads/TestFlightSDK1.0.rar'
    ))
    downloader.expects(:download).raises(Pod::Downloader::Http::UnsupportedFileTypeError)
    downloader.download rescue nil

    downloader = Pod::Downloader.for_pod(stub_pod_with_source(
      :http => 'https://testflightapp.com/media/sdk-downloads/TestFlightSDK1.0',
      :type => :rar
    ))
    downloader.expects(:download).raises(Pod::Downloader::Http::UnsupportedFileTypeError)
    downloader.download rescue nil

  end

  it 'should move unpacked contents to parent dir when archive contains only a folder (#727)' do
    downloader = Pod::Downloader.for_pod(stub_pod_with_source(
      :http => 'http://www.openssl.org/source/openssl-1.0.0a.tar.gz'
    ))
    downloader.download
    # Archive contains one folder, which contains 49 items. The archive is 1, and the
    # parent folder that we moved stuff out of is 1.
    Dir.glob(downloader.target_path + '*').count.should == 49 + 1 + 1

    downloader = Pod::Downloader.for_pod(stub_pod_with_source(
      :http => 'https://testflightapp.com/media/sdk-downloads/TestFlightSDK1.0.zip'
    ))
    downloader.download
    # Archive contains 4 files, and the archive is 1
    Dir.glob(downloader.target_path + '*').count.should == 4 + 1
  end

  it 'should flatten zip archives, when the spec explicitly demands it' do
    downloader = Pod::Downloader.for_pod(stub_pod_with_source(
      :http => 'https://github.com/kevinoneill/Useful-Bits/archive/1.0.zip',
      :flatten => true
    ))
    downloader.download
    # Archive contains one folder, which contains 8 items. The archive is 1, and the
    # parent folder that we moved stuff out of is 1.
    Dir.glob(downloader.target_path + '*').count.should == 8 + 1 + 1
  end
end
