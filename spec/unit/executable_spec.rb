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

      PTY.expects(:spawn).with('/Spa ces/are"/fun/false').once.returns(result)
      Executable.execute_command(cmd, [], true)
    end
    
    it "doesn't hang when the spawned process forks a zombie process with the same STDOUT and STDERR" do
      cmd = ['-e', <<-RB]
        Process.fork { Process.daemon(nil, true); sleep(4) }
        puts 'out'
        warn 'err'
      RB
      Timeout.timeout(2) do
        Executable.execute_command('ruby', cmd, true).should == "out\r\nerr\r\n"
      end
    end
    
    it "captures all output by the subprocess" do
      cmd = ['-e', <<-RB]
        puts 'out'
        warn 'err'
        p 'p'
        print 'print'
      RB
      
      Executable.execute_command('ruby', cmd, true).should == "out\r\nerr\r\n\"p\"\r\nprint"
    end
    
    it "indents output correctly" do
      cmd = ['-e', <<-RB]
        puts 'out'
        warn 'err'
      RB
      
      UI.indentation_level = 4
      
      Executable.execute_command('ruby', cmd, true).should == "    out\r\n    err\r\n"
    end
    
    it "outputs as it goes when verbose" do
      cmd = ['-e', <<-RB]
        puts 'out'
        sleep 0.5
        warn 'err'
      RB
      
      Config.instance.verbose = true
      
      output = StringIO.new
      
      thread = Thread.new { Executable.with_output('ruby', cmd, output) }
      
      # Give Ruby a chance to start.
      sleep 0.3
      
      output.string.should == ''
      
      sleep 0.5
      
      output.string.should == "out\r\n"
      
      sleep 0.5
      
      output.string.should == "out\r\nerr\r\n"
    end
  end
end
