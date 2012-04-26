require File.expand_path("../../../spec_helper", __FILE__)

describe Pod::Generator::Acknowledgements do
  before do
    @podfile = Pod::Podfile.new do
      platform :ios
      xcodeproj "dummy"
    end
    @target_definition = @podfile.target_definitions[:default]

    @sandbox = temporary_sandbox
    @pods = [Pod::LocalPod.new(fixture_spec("banana-lib/BananaLib.podspec"), @sandbox, Pod::Platform.ios)]
    copy_fixture_to_pod("banana-lib", @pods[0])
    @acknowledgements = Pod::Generator::Acknowledgements.new(@target_definition, @pods)
  end

  it "returns the corrent number of licenses (including headera and footnote)" do
    @acknowledgements.licenses.count.should == 3
  end

  it "returns a correctly formed license hash for each pod" do
    @acknowledgements.hash_for_pod(@pods[0]).should == {
      :Type => "PSGroupSpecifier",
      :Title => "BananaLib",
      :FooterText => "Permission is hereby granted ..."
    }
  end

  it "returns a plist containg the licenses" do
    @acknowledgements.plist.should == {
      :Title => "Acknowledgements",
      :StringsTable => "Acknowledgements",
      :PreferenceSpecifiers => @acknowledgements.licenses
    }
  end

  it "adds \"Pods-\" to the beginning of the filename only if necessary" do
    (@acknowledgements.filename.start_with?"Pods-").should.be.true
    (@acknowledgements.filename.start_with?"Pods-Pods-").should.be.false
  end

  it "writes a plist to disk" do
    @acknowledgements.save_in_directory(@sandbox.root).should.be.true
  end
end
