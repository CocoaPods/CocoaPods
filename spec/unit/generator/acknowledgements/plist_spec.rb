require File.expand_path('../../../../spec_helper', __FILE__)

require 'xcodeproj'

describe Pod::Generator::Plist do
  before do
    @file_accessor = fixture_file_accessor('banana-lib/BananaLib.podspec')
    @spec = @file_accessor.spec
    @generator = Pod::Generator::Plist.new([@file_accessor])
    @spec.stubs(:name).returns('POD_NAME')
    @spec.stubs(:license).returns(:type => 'MIT')
    @generator.stubs(:license_text).returns('LICENSE_TEXT')
  end

  it 'returns the correct number of licenses (including header and footnote)' do
    @generator.licenses.count.should == 3
  end

  it 'returns a string for the plist title' do
    @generator.plist_title.should.be.kind_of(String)
  end

  it 'returns a correctly formed license hash for each pod' do
    @generator.hash_for_spec(@spec).should == {
      :Type => 'PSGroupSpecifier',
      :Title => 'POD_NAME',
      :FooterText => 'LICENSE_TEXT',
      :License => 'MIT',
    }
  end

  it 'skips license type in hash when it is nil' do
    @spec.stubs(:license).returns(:type => nil)
    @generator.hash_for_spec(@spec).should == {
      :Type => 'PSGroupSpecifier',
      :Title => 'POD_NAME',
      :FooterText => 'LICENSE_TEXT',
    }
  end

  it 'returns a correctly sanitized license hash for each pod' do
    license_text = 'Copyright © 2013–2014 Boris Bügling'
    @generator.stubs(:license_text).returns(license_text)
    @generator.hash_for_spec(@spec).should == {
      :Type => 'PSGroupSpecifier',
      :Title => 'POD_NAME',
      :FooterText => license_text,
      :License => 'MIT',
    }
  end

  it 'returns nil for a pod with no license text' do
    @generator.expects(:license_text).returns(nil)
    @generator.hash_for_spec(@spec).should.be.nil
  end

  it 'returns a plist containg the licenses' do
    @generator.plist.should == {
      :Title => 'Acknowledgements',
      :StringsTable => 'Acknowledgements',
      :PreferenceSpecifiers => @generator.licenses,
    }
  end

  it 'writes a plist to disk at the given path' do
    basepath = config.sandbox.root + 'Pods-acknowledgements'
    given_path = @generator.class.path_from_basepath(basepath)
    expected_path = config.sandbox.root + 'Pods-acknowledgements.plist'
    Xcodeproj::Plist.expects(:write_to_path).with(equals(@generator.plist), equals(expected_path))
    @generator.save_as(given_path)
  end
end
