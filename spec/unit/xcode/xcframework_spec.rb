require File.expand_path('../../../spec_helper', __FILE__)
require 'cocoapods/xcode'

module Pod
  module Xcode
    describe XCFramework do
      describe 'when parsing `Info.plist`' do
        before do
          @framework_path = fixture('CoconutLib.xcframework')
          @framework = XCFramework.new(@framework_path)
        end

        it 'reads the format version' do
          @framework.format_version.should == Pod::Version.new('1.0')
        end

        it 'reads the framework slices' do
          slices = @framework.slices.sort_by { |s| s.identifier }

          slices.size.should == 7

          slices[0].identifier.should == 'ios-armv7_arm64'
          slices[0].path.should == @framework_path + 'ios-armv7_arm64/CoconutLib.framework'
          slices[0].supported_archs.sort.should == %w(arm64 armv7)
          slices[0].platform.should == Platform.ios
          slices[0].platform_variant.should.be.nil?

          slices[1].identifier.should == 'ios-i386_x86_64-simulator'
          slices[1].path.should == @framework_path + 'ios-i386_x86_64-simulator/CoconutLib.framework'
          slices[1].supported_archs.sort.should == %w(i386 x86_64)
          slices[1].platform.should == Platform.ios
          slices[1].platform_variant.should == :simulator

          slices[2].identifier.should == 'macos-x86_64'
          slices[2].path.should == @framework_path + 'macos-x86_64/CoconutLib.framework'
          slices[2].supported_archs.sort.should == %w(x86_64)
          slices[2].platform.should == Platform.macos
          slices[2].platform_variant.should.be.nil?

          slices[3].identifier.should == 'tvos-arm64'
          slices[3].path.should == @framework_path + 'tvos-arm64/CoconutLib.framework'
          slices[3].supported_archs.sort.should == %w(arm64)
          slices[3].platform.should == Platform.tvos
          slices[3].platform_variant.should.be.nil?

          slices[4].identifier.should == 'tvos-x86_64-simulator'
          slices[4].path.should == @framework_path + 'tvos-x86_64-simulator/CoconutLib.framework'
          slices[4].supported_archs.sort.should == %w(x86_64)
          slices[4].platform.should == Platform.tvos
          slices[4].platform_variant.should == :simulator

          slices[5].identifier.should == 'watchos-armv7k_arm64_32'
          slices[5].path.should == @framework_path + 'watchos-armv7k_arm64_32/CoconutLib.framework'
          slices[5].supported_archs.sort.should == %w(arm64_32 armv7k)
          slices[5].platform.should == Platform.watchos
          slices[5].platform_variant.should.be.nil?

          slices[6].identifier.should == 'watchos-i386-simulator'
          slices[6].path.should == @framework_path + 'watchos-i386-simulator/CoconutLib.framework'
          slices[6].supported_archs.sort.should == %w(i386)
          slices[6].platform.should == Platform.watchos
          slices[6].platform_variant.should == :simulator
        end
      end
    end
  end
end