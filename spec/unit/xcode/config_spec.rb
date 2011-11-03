require File.expand_path('../../../spec_helper', __FILE__)

describe "Pod::Xcode::Config" do
  extend SpecHelper::TemporaryDirectory

  before do
    @config = Pod::Xcode::Config.new('OTHER_LD_FLAGS' => '-framework Foundation')
  end

  it "merges another config hash in place" do
    @config.merge!('HEADER_SEARCH_PATHS' => '/some/path')
    @config.to_hash.should == {
      'OTHER_LD_FLAGS' => '-framework Foundation',
      'HEADER_SEARCH_PATHS' => '/some/path'
    }
  end

  it "appends a value for the same key when merging" do
    @config.merge!('OTHER_LD_FLAGS' => '-l xml2.2.7.3')
    @config.to_hash.should == {
      'OTHER_LD_FLAGS' => '-framework Foundation -l xml2.2.7.3'
    }
  end

  it "creates the config file" do
    @config.merge!('HEADER_SEARCH_PATHS' => '/some/path')
    @config.merge!('OTHER_LD_FLAGS' => '-l xml2.2.7.3')
    @config.save_as(temporary_directory + 'Pods.xcconfig')
    (temporary_directory + 'Pods.xcconfig').read.split("\n").sort.should == [
      "OTHER_LD_FLAGS = -framework Foundation -l xml2.2.7.3",
      "HEADER_SEARCH_PATHS = /some/path"
    ].sort
  end
end
