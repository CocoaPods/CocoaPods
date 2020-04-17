require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Generator::EmbedFrameworksScript do
    it 'installs frameworks by config' do
      frameworks = {
        'Debug' => [Xcode::FrameworkPaths.new('Pods/Loopback.framework'),
                    Xcode::FrameworkPaths.new('Reveal.framework')],
        'Release' => [Xcode::FrameworkPaths.new('Crashlytics.framework')],
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
          install_framework "Crashlytics.framework"
        fi
      SH
    end

    it 'does not install dSYMs or bcsymbolmaps if specified' do
      frameworks = {
        'Debug' => [Xcode::FrameworkPaths.new('Pods/Loopback.framework', 'Pods/Loopback.framework.dSYM',
                                              ['7724D6B4-C7DD-31F0-80C6-EE818ED30B07.bcsymbolmap',
                                               'B724D6B4-C7DD-31F0-80C6-EE818ED30B0B.bcsymbolmap']),
                    Xcode::FrameworkPaths.new('Reveal.framework')],
        'Release' => [Xcode::FrameworkPaths.new('Crashlytics.framework', 'Crashlytics.framework.dSYM',
                                                ['ABCD1234.bcsymbolmap', 'WXYZ5678.bcsymbolmap'])],
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
          install_framework "Crashlytics.framework"
        fi
      SH
      result.should.not.include 'Pods/Loopback.framework.dSYM'
      result.should.not.include 'Crashlytics.framework.dSYM'
      result.should.not.include '7724D6B4-C7DD-31F0-80C6-EE818ED30B07.bcsymbolmap'
      result.should.not.include 'B724D6B4-C7DD-31F0-80C6-EE818ED30B0B.bcsymbolmap'
      result.should.not.include 'ABCD1234.bcsymbolmap'
      result.should.not.include 'WXYZ5678.bcsymbolmap'
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
