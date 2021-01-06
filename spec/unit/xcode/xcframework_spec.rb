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

        it 'returns the name of the framework' do
          @framework.name.should == 'CoconutLib'
        end

        describe '.framework packages' do
          it 'reads the framework slices' do
            slices = @framework.slices.sort_by(&:identifier)

            slices.size.should == 7

            slices[0].identifier.should == 'ios-armv7_arm64'
            slices[0].path.should == @framework_path + 'ios-armv7_arm64/CoconutLib.framework'
            slices[0].binary_path.should == @framework_path + 'ios-armv7_arm64/CoconutLib.framework/CoconutLib'
            slices[0].supported_archs.sort.should == %w(arm64 armv7)
            slices[0].platform.should == Platform.ios
            slices[0].platform_variant.should.be.nil?
            slices[0].package_type.should == :framework

            slices[1].identifier.should == 'ios-i386_x86_64-simulator'
            slices[1].path.should == @framework_path + 'ios-i386_x86_64-simulator/CoconutLib.framework'
            slices[1].binary_path.should == @framework_path + 'ios-i386_x86_64-simulator/CoconutLib.framework/CoconutLib'
            slices[1].supported_archs.sort.should == %w(i386 x86_64)
            slices[1].platform.should == Platform.ios
            slices[1].platform_variant.should == :simulator
            slices[1].package_type.should == :framework

            slices[2].identifier.should == 'macos-x86_64'
            slices[2].path.should == @framework_path + 'macos-x86_64/CoconutLib.framework'
            slices[2].binary_path.should == @framework_path + 'macos-x86_64/CoconutLib.framework/CoconutLib'
            slices[2].supported_archs.sort.should == %w(x86_64)
            slices[2].platform.should == Platform.macos
            slices[2].platform_variant.should.be.nil?
            slices[2].package_type.should == :framework

            slices[3].identifier.should == 'tvos-arm64'
            slices[3].path.should == @framework_path + 'tvos-arm64/CoconutLib.framework'
            slices[3].binary_path.should == @framework_path + 'tvos-arm64/CoconutLib.framework/CoconutLib'
            slices[3].supported_archs.sort.should == %w(arm64)
            slices[3].platform.should == Platform.tvos
            slices[3].platform_variant.should.be.nil?
            slices[3].package_type.should == :framework

            slices[4].identifier.should == 'tvos-x86_64-simulator'
            slices[4].path.should == @framework_path + 'tvos-x86_64-simulator/CoconutLib.framework'
            slices[4].binary_path.should == @framework_path + 'tvos-x86_64-simulator/CoconutLib.framework/CoconutLib'
            slices[4].supported_archs.sort.should == %w(x86_64)
            slices[4].platform.should == Platform.tvos
            slices[4].platform_variant.should == :simulator
            slices[4].package_type.should == :framework

            slices[5].identifier.should == 'watchos-armv7k_arm64_32'
            slices[5].path.should == @framework_path + 'watchos-armv7k_arm64_32/CoconutLib.framework'
            slices[5].binary_path.should == @framework_path + 'watchos-armv7k_arm64_32/CoconutLib.framework/CoconutLib'
            slices[5].supported_archs.sort.should == %w(arm64_32 armv7k)
            slices[5].platform.should == Platform.watchos
            slices[5].platform_variant.should.be.nil?
            slices[5].package_type.should == :framework

            slices[6].identifier.should == 'watchos-i386-simulator'
            slices[6].path.should == @framework_path + 'watchos-i386-simulator/CoconutLib.framework'
            slices[6].binary_path.should == @framework_path + 'watchos-i386-simulator/CoconutLib.framework/CoconutLib'
            slices[6].supported_archs.sort.should == %w(i386)
            slices[6].platform.should == Platform.watchos
            slices[6].platform_variant.should == :simulator
            slices[6].package_type.should == :framework
          end
        end

        describe 'library packaging' do
          before do
            @framework_path = fixture('xcframeworks/StaticLibrary/CoconutLib.xcframework')
            @framework = XCFramework.new(@framework_path)
          end

          it 'reads the library slices' do
            slices = @framework.slices.sort_by(&:identifier)

            slices.size.should == 8
            slices.all? { |slice| slice.package_type.should == :library }

            slices[0].identifier.should == 'ios-arm64'
            slices[0].path.should == @framework_path + 'ios-arm64/libCoconut.a'
            slices[0].binary_path.should == @framework_path + 'ios-arm64/libCoconut.a'
            slices[0].supported_archs.sort.should == %w(arm64)
            slices[0].platform.should == Platform.ios
            slices[0].platform_variant.should.be.nil?
            slices[0].package_type.should == :library

            slices[1].identifier.should == 'ios-arm64_x86_64-simulator'
            slices[1].path.should == @framework_path + 'ios-arm64_x86_64-simulator/libCoconut.a'
            slices[1].binary_path.should == @framework_path + 'ios-arm64_x86_64-simulator/libCoconut.a'
            slices[1].supported_archs.sort.should == %w(arm64 x86_64)
            slices[1].platform.should == Platform.ios
            slices[1].platform_variant.should == :simulator
            slices[1].package_type.should == :library

            slices[2].identifier.should == 'ios-x86_64-maccatalyst'
            slices[2].path.should == @framework_path + 'ios-x86_64-maccatalyst/libCoconut.a'
            slices[2].binary_path.should == @framework_path + 'ios-x86_64-maccatalyst/libCoconut.a'
            slices[2].supported_archs.sort.should == %w(x86_64)
            slices[2].platform.should == Platform.ios
            slices[2].platform_variant.should == :maccatalyst
            slices[2].package_type.should == :library

            slices[3].identifier.should == 'macos-x86_64'
            slices[3].path.should == @framework_path + 'macos-x86_64/libCoconut.a'
            slices[3].binary_path.should == @framework_path + 'macos-x86_64/libCoconut.a'
            slices[3].supported_archs.sort.should == %w(x86_64)
            slices[3].platform.should == Platform.macos
            slices[3].platform_variant.should.be.nil?
            slices[3].package_type.should == :library

            slices[4].identifier.should == 'tvos-arm64'
            slices[4].path.should == @framework_path + 'tvos-arm64/libCoconut.a'
            slices[4].binary_path.should == @framework_path + 'tvos-arm64/libCoconut.a'
            slices[4].supported_archs.sort.should == %w(arm64)
            slices[4].platform.should == Platform.tvos
            slices[4].platform_variant.should.be.nil?
            slices[4].package_type.should == :library

            slices[5].identifier.should == 'tvos-arm64_x86_64-simulator'
            slices[5].path.should == @framework_path + 'tvos-arm64_x86_64-simulator/libCoconut.a'
            slices[5].binary_path.should == @framework_path + 'tvos-arm64_x86_64-simulator/libCoconut.a'
            slices[5].supported_archs.sort.should == %w(arm64 x86_64)
            slices[5].platform.should == Platform.tvos
            slices[5].platform_variant.should == :simulator
            slices[5].package_type.should == :library

            slices[6].identifier.should == 'watchos-arm64_32_armv7k'
            slices[6].path.should == @framework_path + 'watchos-arm64_32_armv7k/libCoconut.a'
            slices[6].binary_path.should == @framework_path + 'watchos-arm64_32_armv7k/libCoconut.a'
            slices[6].supported_archs.sort.should == %w(arm64_32 armv7k)
            slices[6].platform.should == Platform.watchos
            slices[6].platform_variant.should.be.nil?
            slices[6].package_type.should == :library

            slices[7].identifier.should == 'watchos-arm64_i386_x86_64-simulator'
            slices[7].path.should == @framework_path + 'watchos-arm64_i386_x86_64-simulator/libCoconut.a'
            slices[7].binary_path.should == @framework_path + 'watchos-arm64_i386_x86_64-simulator/libCoconut.a'
            slices[7].supported_archs.sort.should == %w(arm64 i386 x86_64)
            slices[7].platform.should == Platform.watchos
            slices[7].platform_variant.should == :simulator
            slices[7].package_type.should == :library
          end
        end
      end
    end
  end
end
