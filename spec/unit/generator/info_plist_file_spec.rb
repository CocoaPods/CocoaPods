require File.expand_path('../../../spec_helper', __FILE__)

describe Pod::Generator::InfoPlistFile do
  describe '#target_version' do
    it 'returns 1.0.0 for the aggregate target' do
      generator = Pod::Generator::InfoPlistFile.new(fixture_aggregate_target)
      generator.target_version.should == '1.0.0'
    end

    it 'returns the specification\'s version for the pod target' do
      generator = Pod::Generator::InfoPlistFile.new(fixture_pod_target('orange-framework/OrangeFramework.podspec'))
      generator.target_version.should == '0.1.0'
    end
  end

  it 'replaces the version in the generated plist' do
    generator = Pod::Generator::InfoPlistFile.new(fixture_pod_target('orange-framework/OrangeFramework.podspec'))
    generator.generate.should.include "<key>CFBundleShortVersionString</key>\n  <string>0.1.0</string>"
  end

  it 'generates a valid Info.plist file' do
    generator = Pod::Generator::InfoPlistFile.new(mock('Target'))
    file = temporary_directory + 'Info.plist'
    generator.save_as(file)
    `plutil -lint #{file}`
    $?.should.be.success
  end
end
