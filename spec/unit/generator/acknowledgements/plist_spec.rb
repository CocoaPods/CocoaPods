require File.expand_path("../../../../spec_helper", __FILE__)

describe Pod::Generator::Plist do
  before do
    @file_accessor = fixture_file_accessor('banana-lib/BananaLib.podspec')
    @spec = @file_accessor.spec
    @plist = Pod::Generator::Plist.new([@file_accessor])
    @spec.stubs(:name).returns("POD_NAME")
    @plist.stubs(:license_text).returns("LICENSE_TEXT")
  end

  it "returns the correct number of licenses (including header and footnote)" do
    @plist.licenses.count.should == 3
  end

  it "returns a string for the plist title" do
    @plist.plist_title.should.be.kind_of(String)
  end

  it "returns a correctly formed license hash for each pod" do
    @plist.hash_for_spec(@spec).should == {
      :Type => "PSGroupSpecifier",
      :Title => "POD_NAME",
      :FooterText => "LICENSE_TEXT"
    }
  end

  it "returns nil for a pod with no license text" do
    @plist.expects(:license_text).returns(nil)
    @plist.hash_for_spec(@spec).should.be.nil
  end

  it "returns a plist containg the licenses" do
    @plist.plist.should == {
      :Title => "Acknowledgements",
      :StringsTable => "Acknowledgements",
      :PreferenceSpecifiers => @plist.licenses
    }
  end

  it "writes a plist to disk at the given path" do
    basepath = config.sandbox.root + "Pods-acknowledgements"
    given_path = @plist.class.path_from_basepath(basepath)
    expected_path = config.sandbox.root + "Pods-acknowledgements.plist"
    Xcodeproj.expects(:write_plist).with(equals(@plist.plist), equals(expected_path))
    @plist.save_as(given_path)
  end
end
