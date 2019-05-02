require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Generator::InfoPlistFile do
    it 'replaces the version in the generated plist' do
      generator = Generator::InfoPlistFile.new('0.1.0', Platform.new(:ios, '6.0'))
      generator.generate.should.include "<key>CFBundleShortVersionString</key>\n  <string>0.1.0</string>"
    end

    it 'generates a valid Info.plist file' do
      generator = Generator::InfoPlistFile.new('1.0.0', Platform.new(:ios, '6.0'))
      file = temporary_directory + 'Info.plist'
      generator.save_as(file)
      `plutil -lint #{file}`
      $?.should.be.success
    end if Executable.which('plutil')

    it 'generates a correct Info.plist file' do
      generator = Generator::InfoPlistFile.new('1.0.0', Platform.new(:ios, '6.0'))
      file = temporary_directory + 'Info.plist'
      generator.save_as(file)
      Xcodeproj::Plist.read_from_path(file).should == {
        'CFBundleDevelopmentRegion' => 'en',
        'CFBundleExecutable' => '${EXECUTABLE_NAME}',
        'CFBundleIdentifier' => '${PRODUCT_BUNDLE_IDENTIFIER}',
        'CFBundleInfoDictionaryVersion' => '6.0',
        'CFBundleName' => '${PRODUCT_NAME}',
        'CFBundlePackageType' => 'FMWK',
        'CFBundleShortVersionString' => '1.0.0',
        'CFBundleSignature' => '????',
        'CFBundleVersion' => '${CURRENT_PROJECT_VERSION}',
        'NSPrincipalClass' => '',
      }
    end

    it 'sets the package type' do
      generator = Generator::InfoPlistFile.new('1.0.0', Platform.new(:ios, '6.0'), :appl)
      file = temporary_directory + 'Info.plist'
      generator.save_as(file)
      Xcodeproj::Plist.read_from_path(file).should == {
        'CFBundleDevelopmentRegion' => 'en',
        'CFBundleExecutable' => '${EXECUTABLE_NAME}',
        'CFBundleIdentifier' => '${PRODUCT_BUNDLE_IDENTIFIER}',
        'CFBundleInfoDictionaryVersion' => '6.0',
        'CFBundleName' => '${PRODUCT_NAME}',
        'CFBundlePackageType' => 'APPL',
        'CFBundleShortVersionString' => '1.0.0',
        'CFBundleSignature' => '????',
        'CFBundleVersion' => '${CURRENT_PROJECT_VERSION}',
        'NSPrincipalClass' => '',
      }
    end

    it 'adds NSPrincipalClass for OSX platform' do
      generator = Generator::InfoPlistFile.new('1.0.0', Platform.new(:osx, '10.8'), :appl)
      file = temporary_directory + 'Info.plist'
      generator.save_as(file)
      Xcodeproj::Plist.read_from_path(file).should == {
        'CFBundleDevelopmentRegion' => 'en',
        'CFBundleExecutable' => '${EXECUTABLE_NAME}',
        'CFBundleIdentifier' => '${PRODUCT_BUNDLE_IDENTIFIER}',
        'CFBundleInfoDictionaryVersion' => '6.0',
        'CFBundleName' => '${PRODUCT_NAME}',
        'CFBundlePackageType' => 'APPL',
        'CFBundleShortVersionString' => '1.0.0',
        'CFBundleSignature' => '????',
        'CFBundleVersion' => '${CURRENT_PROJECT_VERSION}',
        'NSPrincipalClass' => 'NSApplication',
      }
    end

    it 'includes additional entries if requested' do
      generator = Generator::InfoPlistFile.new('1.0.0', Platform.new(:ios, '10.8'), :appl, 'UILaunchStoryboardName' => 'LaunchScreen')
      file = temporary_directory + 'Info.plist'
      generator.save_as(file)
      Xcodeproj::Plist.read_from_path(file).should == {
        'CFBundleDevelopmentRegion' => 'en',
        'CFBundleExecutable' => '${EXECUTABLE_NAME}',
        'CFBundleIdentifier' => '${PRODUCT_BUNDLE_IDENTIFIER}',
        'CFBundleInfoDictionaryVersion' => '6.0',
        'CFBundleName' => '${PRODUCT_NAME}',
        'CFBundlePackageType' => 'APPL',
        'CFBundleShortVersionString' => '1.0.0',
        'CFBundleSignature' => '????',
        'CFBundleVersion' => '${CURRENT_PROJECT_VERSION}',
        'NSPrincipalClass' => '',
        'UILaunchStoryboardName' => 'LaunchScreen',
      }
    end

    it 'properly formats serialized arrays' do
      generator = Generator::InfoPlistFile.new('1.0.0', Platform.new(:ios, '6.0'))
      generator.send(:to_plist, 'array' => %w(a b)).should == <<-PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>array</key>
  <array>
    <string>a</string>
    <string>b</string>
  </array>
</dict>
</plist>
      PLIST
    end

    it 'includes boolean values' do
      generator = Generator::InfoPlistFile.new('1.0.0', Platform.new(:ios, '6.0'))
      generator.send(:to_plist, 'MyDictionary' => { 'MyTrue' => true, 'MyFalse' => false
                                                  }).should == <<-PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>MyDictionary</key>
  <dict>
    <key>MyFalse</key>
    <false/>
    <key>MyTrue</key>
    <true/>
  </dict>
</dict>
</plist>
      PLIST
    end

    it 'uses the specified bundle_package_type' do
      generator = Generator::InfoPlistFile.new('1.0.0', Platform.new(:ios, '6.0'), :bndl)
      file = temporary_directory + 'Info.plist'
      generator.save_as(file)
      Xcodeproj::Plist.read_from_path(file)['CFBundlePackageType'].should == 'BNDL'
    end

    it 'does not include a CFBundleExecutable for bundles' do
      generator = Generator::InfoPlistFile.new('1.0.0', Platform.new(:ios, '6.0'), :bndl)
      file = temporary_directory + 'Info.plist'
      generator.save_as(file)
      Xcodeproj::Plist.read_from_path(file).should.not.key('CFBundleExecutable')
    end
  end
end
