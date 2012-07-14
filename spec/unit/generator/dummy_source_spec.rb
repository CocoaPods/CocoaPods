require File.expand_path('../../../spec_helper', __FILE__)

describe Pod::Generator::DummySource do
  extend SpecHelper::TemporaryDirectory

  before do
    setup_temporary_directory
  end

  after do
    teardown_temporary_directory
  end

  it "generates a dummy sourcefile with the appropriate class for the class name identifier" do
    generator = Pod::Generator::DummySource.new('SomeIdentification')
    file = temporary_directory + 'PodsDummy.m'
    generator.save_as(file)
    file.read.should == <<-EOS
@interface PodsDummy_SomeIdentification : NSObject
@end
@implementation PodsDummy_SomeIdentification
@end
EOS
  end

it "generates a dummy sourcefile with the appropriate class, replacing non-alphanumeric characters with underscores" do
  generator = Pod::Generator::DummySource.new('This!has_non-alphanumeric+characters in it.0123456789')
  file = temporary_directory + 'PodsDummy.m'
  generator.save_as(file)
  file.read.should == <<-EOS
@interface PodsDummy_This_has_non_alphanumeric_characters_in_it_0123456789 : NSObject
@end
@implementation PodsDummy_This_has_non_alphanumeric_characters_in_it_0123456789
@end
EOS
  end

end
