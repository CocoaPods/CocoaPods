require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Platform" do
  before do
    @platform = Pod::Platform.new(:ios)
  end

  it "exposes it's symbolic name" do
    @platform.name.should == :ios
  end

  it "can be compared for equality with another platform with the same symbolic name" do
    @platform.should == Pod::Platform.new(:ios)
  end

  it "can be compared for equality with a matching symbolic name (backwards compatibility reasons)" do
    @platform.should == :ios
  end

  it "presents an accurate string representation" do
    @platform.to_s.should               == "iOS"
    Pod::Platform.new(:osx).to_s.should == 'OS X'
    Pod::Platform.new(nil).to_s.should  == "iOS - OS X"
  end

  it "uses it's name as it's symbold version" do
    @platform.to_sym.should == :ios
  end
end

describe "Pod::Platform with a nil value" do
  before do
    @platform = Pod::Platform.new(nil)
  end

  it "behaves like a nil object" do
    @platform.should.be.nil
  end
end
