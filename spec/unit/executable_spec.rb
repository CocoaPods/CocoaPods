require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Executable do
    it 'shows the actual command on failure' do
      e = lambda do
        Executable.execute_command('false',
                                   [''], true)
      end.should.raise Informative
      e.message.should.match(/false/)
    end

    it 'should support spaces in the full path of the command' do
      cmd = '/Spa ces/are"/fun/false'
      Executable.stubs(:`).returns(cmd)
      result = mock
      result.stubs(:success?).returns(true)

      systemu = mock
      systemu.stubs(:systemu).returns(result)
      SystemUniversal.expects(:new).with("#{cmd.shellescape} ", :stdout => [], :stderr => []).once.returns(systemu)
      Executable.execute_command(cmd, [], true)
    end
  end
end
