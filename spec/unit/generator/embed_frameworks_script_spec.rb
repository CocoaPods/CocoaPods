require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Generator::EmbedFrameworksScript do
    it 'installs frameworks by config' do
      frameworks = {
        'Debug' => [Xcode::FrameworkPaths.new('Pods/Loopback.framework'), Xcode::FrameworkPaths.new('Reveal.framework')],
        'Release' => [Xcode::FrameworkPaths.new('CrashlyticsFramework.framework')],
      }
      generator = Pod::Generator::EmbedFrameworksScript.new(frameworks, {})
      result = generator.send(:script)
      result.should.include <<-SH.strip_heredoc
        if [[ "$CONFIGURATION" == "Debug" ]]; then
          install_framework "Pods/Loopback.framework"
          install_framework "Reveal.framework"
        fi
      SH
      result.should.include <<-SH.strip_heredoc
        if [[ "$CONFIGURATION" == "Release" ]]; then
          install_framework "CrashlyticsFramework.framework"
        fi
      SH
    end

    it 'installs bcsymbolmaps if specified' do
      frameworks = {
        'Debug' => [Xcode::FrameworkPaths.new('Pods/Loopback.framework', nil,
                                              ['7724D6B4-C7DD-31F0-80C6-EE818ED30B07.bcsymbolmap', 'B724D6B4-C7DD-31F0-80C6-EE818ED30B0B.bcsymbolmap']),
                    Xcode::FrameworkPaths.new('Reveal.framework')],
        'Release' => [Xcode::FrameworkPaths.new('CrashlyticsFramework.framework', nil, ['ABCD1234.bcsymbolmap'])],
      }
      generator = Pod::Generator::EmbedFrameworksScript.new(frameworks, {})
      result = generator.send(:script)
      result.should.include <<-SH.strip_heredoc
        if [[ "$CONFIGURATION" == "Debug" ]]; then
          install_framework "Pods/Loopback.framework"
          install_bcsymbolmap "7724D6B4-C7DD-31F0-80C6-EE818ED30B07.bcsymbolmap"
          install_bcsymbolmap "B724D6B4-C7DD-31F0-80C6-EE818ED30B0B.bcsymbolmap"
          install_framework "Reveal.framework"
        fi
      SH
      result.should.include <<-SH.strip_heredoc
        if [[ "$CONFIGURATION" == "Release" ]]; then
          install_framework "CrashlyticsFramework.framework"
          install_bcsymbolmap "ABCD1234.bcsymbolmap"
        fi
      SH
    end

    it 'installs intermediate XCFramework slices' do
      xcframework = Xcode::XCFramework.new(fixture('CoconutLib.xcframework'))
      generator = Pod::Generator::EmbedFrameworksScript.new({}, 'Debug' => [xcframework])
      result = generator.send(:script)
      result.should.include <<-SH.strip_heredoc
        if [[ "$CONFIGURATION" == "Debug" ]]; then
          install_framework "${PODS_XCFRAMEWORKS_BUILD_DIR}/CoconutLib/CoconutLib.framework"
        fi
      SH
    end
  end
end
