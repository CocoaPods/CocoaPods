require File.expand_path('../../../spec_helper', __FILE__)

describe Pod::Generator::TargetHeader do

  before do
    specification = fixture_spec('banana-lib/BananaLib.podspec')
    @gen = Pod::Generator::TargetHeader.new([specification])
  end

  it "generates a header files wihc include the CocoaPods definition" do
    file = temporary_directory + 'PodsDummy.m'
    @gen.save_as(file)
    file.read.should == <<-EOS.strip_heredoc
    #define __COCOA_PODS

    #define __POD_BananaLib
    EOS
  end
end

