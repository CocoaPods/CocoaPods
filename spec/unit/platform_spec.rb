require File.expand_path('../../spec_helper', __FILE__)

describe Pod::Platform do
  it "returns a new Platform instance" do
    Pod::Platform.ios.should == Pod::Platform.new(:ios)
    Pod::Platform.osx.should == Pod::Platform.new(:osx)
  end

  before do
    @platform = Pod::Platform.ios
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
    Pod::Platform.new(:ios, { :deployment_target => '5.0.0' }).to_s.should == 'iOS 5.0.0'
    Pod::Platform.new(:osx, { :deployment_target => '10.7' }).to_s.should == 'OS X 10.7'
  end

  it "correctly indicates if it supports another platfrom" do
    ios4 = Pod::Platform.new(:ios, { :deployment_target => '4.0.0' })
    ios5 = Pod::Platform.new(:ios, { :deployment_target => '5.0.0' })
    ios5.should.support?(ios4)
    ios4.should.not.support?(ios5)
    osx6 = Pod::Platform.new(:osx, { :deployment_target => '10.6' })
    osx7 = Pod::Platform.new(:osx, { :deployment_target => '10.7' })
    osx7.should.support?(osx6)
    osx6.should.not.support?(osx7)
    both = Pod::Platform.new(nil)
    both.should.support?(ios4)
    both.should.support?(osx6)
    both.should.support?(nil)
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
