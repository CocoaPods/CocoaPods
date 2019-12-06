require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Generator::EmbedFrameworksScript do
    it 'returns the embed frameworks script' do
      frameworks = {
        'Debug' => [Xcode::FrameworkPaths.new('Pods/Loopback.framework', 'Pods/Loopback.framework.dSYM', ['7724D6B4-C7DD-31F0-80C6-EE818ED30B07.bcsymbolmap', 'B724D6B4-C7DD-31F0-80C6-EE818ED30B0B.bcsymbolmap']),
                    Xcode::FrameworkPaths.new('Reveal.framework')],
        'Release' => [Xcode::FrameworkPaths.new('CrashlyticsFramework.framework')],
      }
      generator = Pod::Generator::EmbedFrameworksScript.new(frameworks)
      generator.send(:script).should.include <<-SH.strip_heredoc
        if [[ "$CONFIGURATION" == "Debug" ]]; then
          install_framework "Pods/Loopback.framework"
          install_dsym "Pods/Loopback.framework.dSYM"
          install_bcsymbolmap "7724D6B4-C7DD-31F0-80C6-EE818ED30B07.bcsymbolmap"
          install_bcsymbolmap "B724D6B4-C7DD-31F0-80C6-EE818ED30B0B.bcsymbolmap"
          install_framework "Reveal.framework"
        fi
      SH
      generator.send(:script).should.include <<-SH.strip_heredoc
        if [[ "$CONFIGURATION" == "Release" ]]; then
          install_framework "CrashlyticsFramework.framework"
        fi
      SH
    end
  end
end
