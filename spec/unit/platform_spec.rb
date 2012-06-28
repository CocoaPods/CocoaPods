require File.expand_path('../../spec_helper', __FILE__)

describe Pod::Platform do
  describe "by default" do
    it "returns a new Platform instance" do
      Pod::Platform.ios.should == Pod::Platform.new(:ios)
      Pod::Platform.osx.should == Pod::Platform.new(:osx)
    end

    it "can be initialized from another platform" do
      platform = Pod::Platform.new(:ios)
      new = Pod::Platform.new(platform)
      new.should == platform
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

    it "can be compared for equality with another platform with the same symbolic name and the same deployment target" do
      @platform.should.not == Pod::Platform.new(:ios, '4.0')
      Pod::Platform.new(:ios, '4.0').should == Pod::Platform.new(:ios, '4.0')
    end

    it "can be compared for equality with a matching symbolic name (backwards compatibility reasons)" do
      @platform.should == :ios
    end

    it "presents an accurate string representation" do
      @platform.to_s.should == "iOS"
      Pod::Platform.new(:osx).to_s.should == 'OS X'
      Pod::Platform.new(:ios, '5.0.0').to_s.should == 'iOS 5.0.0'
      Pod::Platform.new(:osx, '10.7').to_s.should  == 'OS X 10.7'
    end

    it "uses it's name as it's symbold version" do
      @platform.to_sym.should == :ios
    end

    it "allows to specify the deployment target on initialization" do
      p = Pod::Platform.new(:ios, '4.0.0')
      p.deployment_target.should == Pod::Version.new('4.0.0')
    end

    it "allows to specify the deployment target in a hash on initialization (backwards compatibility from 0.6)" do
      p = Pod::Platform.new(:ios, { :deployment_target => '4.0.0' })
      p.deployment_target.should == Pod::Version.new('4.0.0')
    end

    it "provides a default deployment target on initialization" do
      p = Pod::Platform.new(:ios)
      p.deployment_target.should == Pod::Version.new('4.3')
    end
  end

  describe "regarding supporting platforms" do
    it "supports platforms with the same operating system" do
      p1 = Pod::Platform.new(:ios)
      p2 = Pod::Platform.new(:ios)
      p1.should.supports?(p2)

      p1 = Pod::Platform.new(:osx)
      p2 = Pod::Platform.new(:osx)
      p1.should.supports?(p2)
    end

    it "supports a platform with a lower or equal deployment_target" do
      p1 = Pod::Platform.new(:ios, '5.0')
      p2 = Pod::Platform.new(:ios, '4.0')
      p1.should.supports?(p1)
      p1.should.supports?(p2)
      p2.should.not.supports?(p1)
    end

    it "doesn't supports a platform with a different operating system" do
      p1 = Pod::Platform.new(:ios)
      p2 = Pod::Platform.new(:osx)
      p1.should.not.supports?(p2)
    end
  end
end
