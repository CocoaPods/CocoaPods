require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Podfile" do
  it "loads from a file" do
    podfile = Pod::Podfile.from_file(fixture('Podfile'))
    podfile.defined_in_file.should == fixture('Podfile')
  end

  it "assigns the platform attribute" do
    podfile = Pod::Podfile.new { platform :ios }
    podfile.platform.should == :ios
  end

  it "adds dependencies" do
    podfile = Pod::Podfile.new { dependency 'ASIHTTPRequest'; dependency 'SSZipArchive', '>= 0.1' }
    podfile.dependencies.size.should == 2
    podfile.dependency_by_name('ASIHTTPRequest').should == Pod::Dependency.new('ASIHTTPRequest')
    podfile.dependency_by_name('SSZipArchive').should == Pod::Dependency.new('SSZipArchive', '>= 0.1')
  end

  it "specifies if BridgeSupport metadata should be generated" do
    podfile = Pod::Podfile.new { generate_bridge_support! }
    podfile.generate_bridge_support?.should == true
  end

  describe "concerning validations" do
    it "raises if no platform is specified" do
      exception = lambda {
        Pod::Podfile.new {}.validate!
      }.should.raise Pod::Informative
      exception.message.should.include "platform"
    end

    it "raises if an invalid platform is specified" do
      exception = lambda {
        Pod::Podfile.new { platform :windows }.validate!
      }.should.raise Pod::Informative
      exception.message.should.include "platform"
    end

    it "raises if no dependencies were specified" do
      exception = lambda {
        Pod::Podfile.new {}.validate!
      }.should.raise Pod::Informative
      exception.message.should.include "dependencies"
    end
  end
end
