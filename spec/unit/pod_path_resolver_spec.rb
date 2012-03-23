require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::PodPathResolver" do
  it "should default to a path underneath source root" do
    podfile = Pod::Podfile.new {platform :ios; xcodeproj 'foo.xcodeproj'}
    resolver = Pod::PodPathResolver.new(podfile)
    resolver.pods_root.should == "$(SRCROOT)/Pods"
  end

  it "should work with source root one level deeper" do
    podfile = Pod::Podfile.new {platform :ios; xcodeproj 'subdir/foo.xcodeproj'}
    resolver = Pod::PodPathResolver.new(podfile)
    resolver.pods_root.should == "$(SRCROOT)/../Pods"
  end
end
