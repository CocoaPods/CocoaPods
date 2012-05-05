require File.expand_path("../../../../spec_helper", __FILE__)

describe Pod::Generator::Plist do
  before do
    @sandbox = temporary_sandbox
    @target_definition = mock()
    @pods = [mock()]
    @pods[0].expects(:license_text).returns("LICENSE_TEXT").at_least_once
    @pods[0].expects(:name).returns("POD_NAME").at_least_once
    @plist = Pod::Generator::Plist.new(@target_definition, @pods)
  end

  it "returns the correct number of licenses (including header and footnote)" do
    @plist.licenses.count.should == 3
  end

  it "returns a correctly formed license hash for each pod" do
    @plist.hash_for_pod(@pods[0]).should == {
      :Type => "PSGroupSpecifier",
      :Title => "POD_NAME",
      :FooterText => "LICENSE_TEXT"
    }
  end

  it "returns nil for a pod with no license text" do
    @pods[0].unstub(:license_text)
    @pods[0].unstub(:name)
    @pods[0].expects(:license_text).returns(nil)
    @plist.hash_for_pod(@pods[0]).should.be.nil
  end

  it "returns a plist containg the licenses" do
    @plist.plist.should == {
      :Title => "Acknowledgements",
      :StringsTable => "Acknowledgements",
      :PreferenceSpecifiers => @plist.licenses
    }
  end

  it "writes a plist to disk at the given path" do
    path = @sandbox.root + "Pods-Acknowledgements.plist"
    Xcodeproj.expects(:write_plist).with(equals(@plist.plist), equals(path))
    @plist.save_as(path)
  end
end
