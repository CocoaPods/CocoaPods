require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::PodPathResolver" do
  it "should default to a path underneath source root" do
    target_definition = Pod::Podfile::TargetDefinition.new(:default)
    target_definition.xcodeproj = 'foo.xcodeproj'
    resolver = Pod::PodPathResolver.new(target_definition)
    resolver.pods_root.should == "$(SRCROOT)/Pods"
  end

  it "should work with source root one level deeper" do
    target_definition = Pod::Podfile::TargetDefinition.new(:default)
    target_definition.xcodeproj = 'subdir/foo.xcodeproj'
    resolver = Pod::PodPathResolver.new(target_definition)
    resolver.pods_root.should == "$(SRCROOT)/../Pods"
  end
end
