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

      Open3.expects(:popen3).with('/Spa ces/are"/fun/false').once.returns(result)
      Executable.execute_command(cmd, [], true)
    end

    it "doesn't hang when the spawned process forks a zombie process with the same STDOUT and STDERR" do
      cmd = ['-e', <<-RB]
        Process.fork { Process.daemon(nil, true); sleep(4) }
        puts 'out'
      RB
      Timeout.timeout(2) do
        Executable.execute_command('ruby', cmd, true).should == "out\n"
      end
    end
    
    it "returns the right output" do
      cmd = ['-e', <<-RB]
        puts 'foo'
        puts 'bar'
      RB
      Timeout.timeout(2) do
        Executable.execute_command('ruby', cmd, true).should == "foo\nbar\n"
      end
    end
  end
end
