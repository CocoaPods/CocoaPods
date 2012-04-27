require File.expand_path('../../../spec_helper', __FILE__)

describe Pod::Generator::DummySource do
  extend SpecHelper::TemporaryDirectory

  before do
    setup_temporary_directory
  end
  
  after do
    teardown_temporary_directory
  end

  it "generates a dummy sourcefile with the appropriate class" do
    generator = Pod::Generator::DummySource.new("Pods")
    file = temporary_directory + 'PodsDummy.m'
    generator.save_as(file)
    file.read.should == <<-EOS
@interface PodsDummy : NSObject
@end
@implementation PodsDummy
@end
EOS
  end  
end
