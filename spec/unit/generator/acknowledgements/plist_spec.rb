require File.expand_path("../../../../spec_helper", __FILE__)

describe Pod::Generator::Plist do
  before do
    @podfile = Pod::Podfile.new do
      platform :ios
      xcodeproj "dummy"
    end
    @target_definition = @podfile.target_definitions[:default]

    @sandbox = temporary_sandbox
    @pods = [Pod::LocalPod.new(fixture_spec("banana-lib/BananaLib.podspec"), @sandbox, Pod::Platform.ios)]
    copy_fixture_to_pod("banana-lib", @pods[0])
    @plist = Pod::Generator::Plist.new(@target_definition, @pods)
  end

  it "returns the correct number of licenses (including header and footnote)" do
    @plist.licenses.count.should == 3
  end

  # TODO Test with a pod that has no licence
  it "returns a correctly formed license hash for each pod" do
    @plist.hash_for_pod(@pods[0]).should == {
      :Type => "PSGroupSpecifier",
      :Title => "BananaLib",
      :FooterText => "Permission is hereby granted ..."
    }
  end

  it "returns a plist containg the licenses" do
    @plist.plist.should == {
      :Title => "Acknowledgements",
      :StringsTable => "Acknowledgements",
      :PreferenceSpecifiers => @plist.licenses
    }
  end

  it "writes a plist to disk at the given path" do
    path = @sandbox.root + "#{@target_definition.label}-Acknowledgements.plist"
    Xcodeproj.expects(:write_plist).with(equals(@plist.plist), equals(path))
    @plist.save_as(path)
  end
end
