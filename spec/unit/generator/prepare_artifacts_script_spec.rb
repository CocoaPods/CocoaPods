require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe PrepareArtifactsScript = Generator::PrepareArtifactsScript do
    it 'installs xcframeworks' do
      xcframework = Xcode::XCFramework.new(fixture('CoconutLib.xcframework'))
      generator = PrepareArtifactsScript.new({'Debug' => [xcframework]}, temporary_sandbox.root, Platform.ios)
      generator.send(:script).should.include <<-SH.strip_heredoc
        if [[ "$CONFIGURATION" == "Debug" ]]; then
          install_xcframework "${PODS_ROOT}/../../spec/fixtures/CoconutLib.xcframework" "true" "ios-armv7_arm64/CoconutLib.framework" "ios-i386_x86_64-simulator/CoconutLib.framework"
        fi
      SH
    end

    it 'installs xcframeworks using the correct platform' do
      xcframework = Xcode::XCFramework.new(fixture('CoconutLib.xcframework'))
      generator = PrepareArtifactsScript.new({'Debug' => [xcframework]}, temporary_sandbox.root, Platform.macos)
      generator.send(:script).should.include <<-SH.strip_heredoc
        if [[ "$CONFIGURATION" == "Debug" ]]; then
          install_xcframework "${PODS_ROOT}/../../spec/fixtures/CoconutLib.xcframework" "true" "macos-x86_64/CoconutLib.framework"
        fi
      SH
      generator = PrepareArtifactsScript.new({'Debug' => [xcframework]}, temporary_sandbox.root, Platform.ios)
      generator.send(:script).should.include <<-SH.strip_heredoc
        if [[ "$CONFIGURATION" == "Debug" ]]; then
          install_xcframework "${PODS_ROOT}/../../spec/fixtures/CoconutLib.xcframework" "true" "ios-armv7_arm64/CoconutLib.framework" "ios-i386_x86_64-simulator/CoconutLib.framework"
        fi
      SH
      generator = PrepareArtifactsScript.new({'Debug' => [xcframework]}, temporary_sandbox.root, Platform.watchos)
      generator.send(:script).should.include <<-SH.strip_heredoc
        if [[ "$CONFIGURATION" == "Debug" ]]; then
          install_xcframework "${PODS_ROOT}/../../spec/fixtures/CoconutLib.xcframework" "true" "watchos-i386-simulator/CoconutLib.framework" "watchos-armv7k_arm64_32/CoconutLib.framework"
        fi
      SH
      generator = PrepareArtifactsScript.new({'Debug' => [xcframework]}, temporary_sandbox.root, Platform.tvos)
      generator.send(:script).should.include <<-SH.strip_heredoc
        if [[ "$CONFIGURATION" == "Debug" ]]; then
          install_xcframework "${PODS_ROOT}/../../spec/fixtures/CoconutLib.xcframework" "true" "tvos-x86_64-simulator/CoconutLib.framework" "tvos-arm64/CoconutLib.framework"
        fi
      SH
    end

    it 'does not embed static frameworks' do
      xcframework = Xcode::XCFramework.new(fixture('CoconutLib.xcframework'))
      generator = PrepareArtifactsScript.new({'Debug' => [xcframework]}, temporary_sandbox.root, Platform.ios)
      Xcode::LinkageAnalyzer.stubs(:dynamic_binary?).returns(false)
      # Second argument to `install_xcframework` is a boolean indicating whether to embed the framework
      generator.send(:script).should.include <<-SH.strip_heredoc
        if [[ "$CONFIGURATION" == "Debug" ]]; then
          install_xcframework "${PODS_ROOT}/../../spec/fixtures/CoconutLib.xcframework" "false" "ios-armv7_arm64/CoconutLib.framework" "ios-i386_x86_64-simulator/CoconutLib.framework"
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
      generator = PrepareArtifactsScript.new({'Debug' => [xcframework]}, temporary_sandbox.root, Platform.ios)
      results = generator.generate
      results.should.include <<-SH.strip_heredoc
        install_artifact "${PODS_ROOT}/../../spec/fixtures/CoconutLib.dSYMs/A.dSYM" "${TARGET_BUILD_DIR}" "true"
      SH
      results.should.include <<-SH.strip_heredoc
        install_artifact "${PODS_ROOT}/../../spec/fixtures/CoconutLib.dSYMs/B.dSYM" "${TARGET_BUILD_DIR}" "true"
      SH
    end
  end
end
