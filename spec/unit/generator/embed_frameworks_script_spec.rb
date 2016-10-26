require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Generator::EmbedFrameworksScript do
    before do
      ENV.delete('PARALLEL_CODE_SIGN')
      frameworks = {
        'Debug'   => %w(Pods/Loopback.framework Reveal.framework),
        'Release' => %w(CrashlyticsFramework.framework),
      }
      @generator = Pod::Generator::EmbedFrameworksScript.new(frameworks)
    end
    it 'returns the embed frameworks script' do
      @generator.send(:script).should.include <<-SH.strip_heredoc
        if [[ "$CONFIGURATION" == "Debug" ]]; then
          install_framework "Pods/Loopback.framework"
          install_framework "Reveal.framework"
        fi
      SH
      @generator.send(:script).should.include <<-SH.strip_heredoc
        if [[ "$CONFIGURATION" == "Release" ]]; then
          install_framework "CrashlyticsFramework.framework"
        fi
      SH
    end

    it 'runs codesigning in the background when PARALLEL_CODE_SIGN is set to true' do
      ENV['PARALLEL_CODE_SIGN'] = 'true'
      @generator.send(:script).should.include <<-SH.strip_heredoc
        /usr/bin/codesign --force --sign ${EXPANDED_CODE_SIGN_IDENTITY} ${OTHER_CODE_SIGN_FLAGS} --preserve-metadata=identifier,entitlements "$1" &
      SH
      @generator.send(:script).should.include <<-SH.strip_heredoc
        wait
      SH
    end

    it 'does not run codesigning in the background when PARALLEL_CODE_SIGN is set to true' do
      @generator.send(:script).should.include <<-SH.strip_heredoc
        /usr/bin/codesign --force --sign ${EXPANDED_CODE_SIGN_IDENTITY} ${OTHER_CODE_SIGN_FLAGS} --preserve-metadata=identifier,entitlements "$1"
      SH
      @generator.send(:script).should.not.include <<-SH.strip_heredoc
        /usr/bin/codesign --force --sign ${EXPANDED_CODE_SIGN_IDENTITY} ${OTHER_CODE_SIGN_FLAGS} --preserve-metadata=identifier,entitlements "$1" &
      SH
    end
  end
end
