require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe PrepareArtifactsScript = Generator::PrepareArtifactsScript do
    it 'installs xcframeworks' do
      xcframework = Xcode::XCFramework.new(fixture('CoconutLib.xcframework'))
      generator = PrepareArtifactsScript.new({'Debug' => [xcframework]}, temporary_sandbox.root)
      generator.send(:script).should.include <<-SH.strip_heredoc
        if [[ "$CONFIGURATION" == "Debug" ]]; then
          install_xcframework "${PODS_ROOT}/../../spec/fixtures/CoconutLib.xcframework" "tvos-x86_64-simulator/CoconutLib.framework" "tvos-arm64/CoconutLib.framework" "macos-x86_64/CoconutLib.framework" "ios-armv7_arm64/CoconutLib.framework" "watchos-i386-simulator/CoconutLib.framework" "watchos-armv7k_arm64_32/CoconutLib.framework" "ios-i386_x86_64-simulator/CoconutLib.framework"
        fi
      SH
    end

    it 'installs dSYMs if found' do
      xcframework = Xcode::XCFramework.new(fixture('CoconutLib.xcframework'))
      dsym_path = xcframework.path.dirname + 'CoconutLib.dSYMs'
      PrepareArtifactsScript.stubs(:dsym_paths).returns([
        dsym_path + 'A.dSYM',
        dsym_path + 'B.dSYM'
      ])
      generator = PrepareArtifactsScript.new({'Debug' => [xcframework]}, temporary_sandbox.root)
      results = generator.generate
      results.should.include <<-SH.strip_heredoc
        install_artifact "${PODS_ROOT}/../../spec/fixtures/CoconutLib.dSYMs/A.dSYM" "${TARGET_BUILD_DIR}"
      SH
      results.should.include <<-SH.strip_heredoc
        install_artifact "${PODS_ROOT}/../../spec/fixtures/CoconutLib.dSYMs/B.dSYM" "${TARGET_BUILD_DIR}"
      SH
    end
  end
end
