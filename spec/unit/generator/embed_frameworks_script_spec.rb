require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Generator::EmbedFrameworksScript do
    it 'returns the embed frameworks script' do
      frameworks = {
        'Debug' => [{ :name => 'Loopback.framework', :input_path => 'Pods/Loopback.framework', :dsym_input_path => 'Pods/Loopback.framework.dSYM' }, { :name => 'Reveal.framework', :input_path => 'Reveal.framework' }],
        'Release' => [{ :name => 'CrashlyticsFramework.framework', :input_path => 'CrashlyticsFramework.framework' }],
      }
      generator = Pod::Generator::EmbedFrameworksScript.new(frameworks)
      generator.send(:script).should.include <<-SH.strip_heredoc
        if [[ "$CONFIGURATION" == "Debug" ]]; then
          install_framework "Pods/Loopback.framework"
          install_dsym "Pods/Loopback.framework.dSYM"
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
