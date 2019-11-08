require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Generator::PrepareArtifactsScript do
    it 'installs xcframeworks' do
      xcframework = Xcode::XCFramework.new(fixture('CoconutLib.xcframework'))
      generator = Pod::Generator::PrepareArtifactsScript.new({'Debug' => [xcframework]}, temporary_sandbox.root)
      generator.send(:script).should.include <<-SH.strip_heredoc
        if [[ "$CONFIGURATION" == "Debug" ]]; then
          install_xcframework "${PODS_ROOT}/../../spec/fixtures/CoconutLib.xcframework" "tvos-x86_64-simulator/CoconutLib.framework" "tvos-arm64/CoconutLib.framework" "macos-x86_64/CoconutLib.framework" "ios-armv7_arm64/CoconutLib.framework" "watchos-i386-simulator/CoconutLib.framework" "watchos-armv7k_arm64_32/CoconutLib.framework" "ios-i386_x86_64-simulator/CoconutLib.framework"
        fi
      SH
    end
  end
end
