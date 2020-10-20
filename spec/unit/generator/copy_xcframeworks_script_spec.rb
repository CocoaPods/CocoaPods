require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe CopyXCFrameworksScript = Generator::CopyXCFrameworksScript do
    it 'installs xcframeworks' do
      xcframework = Xcode::XCFramework.new(fixture('CoconutLib.xcframework'))
      generator = CopyXCFrameworksScript.new([xcframework], temporary_sandbox.root, Platform.ios)
      generator.send(:script).should.include <<-SH.strip_heredoc
        install_xcframework "${PODS_ROOT}/../../spec/fixtures/CoconutLib.xcframework" "CoconutLib" "framework" "ios-armv7_arm64" "ios-i386_x86_64-simulator"
      SH
    end

    it 'installs xcframeworks using the correct platform' do
      xcframework = Xcode::XCFramework.new(fixture('CoconutLib.xcframework'))
      generator = CopyXCFrameworksScript.new([xcframework], temporary_sandbox.root, Platform.macos)
      generator.send(:script).should.include <<-SH.strip_heredoc
        install_xcframework "${PODS_ROOT}/../../spec/fixtures/CoconutLib.xcframework" "CoconutLib" "framework" "macos-x86_64"
      SH
      generator = CopyXCFrameworksScript.new([xcframework], temporary_sandbox.root, Platform.ios)
      generator.send(:script).should.include <<-SH.strip_heredoc
        install_xcframework "${PODS_ROOT}/../../spec/fixtures/CoconutLib.xcframework" "CoconutLib" "framework" "ios-armv7_arm64" "ios-i386_x86_64-simulator"
      SH
      generator = CopyXCFrameworksScript.new([xcframework], temporary_sandbox.root, Platform.watchos)
      generator.send(:script).should.include <<-SH.strip_heredoc
        install_xcframework "${PODS_ROOT}/../../spec/fixtures/CoconutLib.xcframework" "CoconutLib" "framework" "watchos-i386-simulator" "watchos-armv7k_arm64_32"
      SH
      generator = CopyXCFrameworksScript.new([xcframework], temporary_sandbox.root, Platform.tvos)
      generator.send(:script).should.include <<-SH.strip_heredoc
        install_xcframework "${PODS_ROOT}/../../spec/fixtures/CoconutLib.xcframework" "CoconutLib" "framework" "tvos-x86_64-simulator" "tvos-arm64"
      SH
    end

    it 'does not embed static frameworks' do
      xcframework = Xcode::XCFramework.new(fixture('CoconutLib.xcframework'))
      generator = CopyXCFrameworksScript.new([xcframework], temporary_sandbox.root, Platform.ios)
      Xcode::LinkageAnalyzer.stubs(:dynamic_binary?).returns(false)
      # Second argument to `install_xcframework` is a boolean indicating whether to embed the framework
      generator.send(:script).should.include 'CoconutLib.xcframework'
    end
  end
end
