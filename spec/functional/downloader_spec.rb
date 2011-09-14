require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Downloader" do
  extend SpecHelper::TemporaryDirectory

  before do
    @dir = temporary_directory + 'banana-lib'
  end

  it "check's out a specific commit" do
    downloader = Pod::Downloader.for_source(@dir,
      :git => fixture('banana-lib'), :commit => '02467b074d4dc9f6a75b8cd3ab80d9bf37887b01'
    )
    downloader.download
    (@dir + 'README').read.strip.should == 'first commit'
  end

  it "check's out a specific tag" do
    downloader = Pod::Downloader.for_source(@dir,
      :git => fixture('banana-lib'), :tag => 'v1.0'
    )
    downloader.download
    (@dir + 'README').read.strip.should == 'v1.0'
  end

  it "removes the .git directory" do
    downloader = Pod::Downloader.for_source(@dir,
      :git => fixture('banana-lib'), :tag => 'v1.0'
    )
    downloader.download
    downloader.clean
    (@dir + '.git').should.not.exist
  end
end

