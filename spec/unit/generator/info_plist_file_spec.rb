require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Generator::InfoPlistFile do
    describe '#target_version' do
      it 'returns 1.0.0 for the aggregate target' do
        generator = Generator::InfoPlistFile.new(fixture_aggregate_target)
        generator.target_version.should == '1.0.0'
      end

      describe 'sanitization' do
        before do
          @root_spec = mock('RootSpec')
          @platform = stub('Platform', :name => :ios)
          pod_target = stub('PodTarget', :root_spec => @root_spec, :platform => @platform)
          @generator = Generator::InfoPlistFile.new(pod_target)
        end

        it 'handles when the version is more than 3 numeric parts' do
          version = Version.new('0.2.0.1')
          @root_spec.stubs(:version).returns(version)
          @generator.target_version.should == '0.2.0'
        end

        it 'handles when the version is less than 3 numeric parts' do
          version = Version.new('0.2')
          @root_spec.stubs(:version).returns(version)
          @generator.target_version.should == '0.2.0'
        end

        it 'handles when the version is a pre-release' do
          version = Version.new('1.0.0-beta.1')
          @root_spec.stubs(:version).returns(version)
          @generator.target_version.should == '1.0.0'

          version = Version.new('1.0-beta.5')
          @root_spec.stubs(:version).returns(version)
          @generator.target_version.should == '1.0.0'
        end
      end

      it 'returns the specification\'s version for the pod target' do
        generator = Generator::InfoPlistFile.new(fixture_pod_target('orange-framework/OrangeFramework.podspec'))
        generator.target_version.should == '0.1.0'
      end
    end

    it 'replaces the version in the generated plist' do
      generator = Generator::InfoPlistFile.new(fixture_pod_target('orange-framework/OrangeFramework.podspec'))
      generator.generate.should.include "<key>CFBundleShortVersionString</key>\n  <string>0.1.0</string>"
    end

    it 'generates a valid Info.plist file' do
      generator = Generator::InfoPlistFile.new(fixture_pod_target('orange-framework/OrangeFramework.podspec'))
      file = temporary_directory + 'Info.plist'
      generator.save_as(file)
      `plutil -lint #{file}`
      $?.should.be.success
    end if Executable.which('plutil')

    it 'generates a correct Info.plist file' do
      generator = Generator::InfoPlistFile.new(mock('Target', :platform => stub(:name => :ios)))
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

    it 'adds UIRequiredDeviceCapabilities for tvOS targets' do
      pod_target = fixture_pod_target('orange-framework/OrangeFramework.podspec')
      pod_target.stubs(:platform).returns(Platform.new(:tvos, '9.0'))
      generator = Generator::InfoPlistFile.new(pod_target)
      file = temporary_directory + 'Info.plist'
      generator.save_as(file)
      Xcodeproj::Plist.read_from_path(file)['UIRequiredDeviceCapabilities'].should == %w(arm64)
    end

    it 'properly formats serialized arrays' do
      generator = Generator::InfoPlistFile.new(mock('Target'))
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

    it 'uses the specified bundle_package_type' do
      target = mock('Target', :platform => stub(:name => :ios))
      generator = Generator::InfoPlistFile.new(target, :bundle_package_type => :bndl)
      file = temporary_directory + 'Info.plist'
      generator.save_as(file)
      Xcodeproj::Plist.read_from_path(file)['CFBundlePackageType'].should == 'BNDL'
    end

    it 'does not include a CFBundleExecutable for bundles' do
      target = mock('Target', :platform => stub(:name => :ios))
      generator = Generator::InfoPlistFile.new(target, :bundle_package_type => :bndl)
      file = temporary_directory + 'Info.plist'
      generator.save_as(file)
      Xcodeproj::Plist.read_from_path(file).should.not.key('CFBundleExecutable')
    end
  end
end
