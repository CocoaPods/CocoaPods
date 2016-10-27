require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Generator::EmbedFrameworksScript do
    it 'returns the embed frameworks script' do
      frameworks = {
        'Debug'   => %w(Pods/Loopback.framework Reveal.framework),
        'Release' => %w(CrashlyticsFramework.framework),
      }
      generator = Pod::Generator::EmbedFrameworksScript.new(frameworks)
      generator.send(:script).should.include <<-SH.strip_heredoc
        if [[ "$CONFIGURATION" == "Debug" ]]; then
          install_framework "Pods/Loopback.framework"
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
