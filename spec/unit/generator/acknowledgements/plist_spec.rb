require File.expand_path("../../../../spec_helper", __FILE__)

describe Pod::Generator::Plist do
  before do
    @file_accessor = fixture_file_accessor('banana-lib/BananaLib.podspec')
    @spec = @file_accessor.spec
    @generator = Pod::Generator::Plist.new([@file_accessor])
    @spec.stubs(:name).returns("POD_NAME")
    @generator.stubs(:license_text).returns("LICENSE_TEXT")
  end

  it "returns the correct number of licenses (including header and footnote)" do
    @generator.licenses.count.should == 3
  end

  it "returns a string for the plist title" do
    @generator.plist_title.should.be.kind_of(String)
  end

  it "returns a correctly formed license hash for each pod" do
    @generator.hash_for_spec(@spec).should == {
      :Type => "PSGroupSpecifier",
      :Title => "POD_NAME",
      :FooterText => "LICENSE_TEXT"
    }
  end

  it "returns nil for a pod with no license text" do
    @generator.expects(:license_text).returns(nil)
    @generator.hash_for_spec(@spec).should.be.nil
  end

  it "returns a plist containg the licenses" do
    @generator.plist.should == {
      :Title => "Acknowledgements",
      :StringsTable => "Acknowledgements",
      :PreferenceSpecifiers => @generator.licenses
    }
  end

  it "writes a plist to disk at the given path" do
    basepath = config.sandbox.root + "Pods-acknowledgements"
    given_path = @generator.class.path_from_basepath(basepath)
    expected_path = config.sandbox.root + "Pods-acknowledgements.plist"
    Xcodeproj.expects(:write_plist).with(equals(@generator.plist), equals(expected_path))
    @generator.save_as(given_path)
  end
end
