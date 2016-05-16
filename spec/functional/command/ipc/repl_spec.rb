require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Command::IPC::Repl do
    before do
      Command::IPC::Repl.any_instance.stubs(:output_pipe).returns(UI)
      Command::IPC::Podfile.any_instance.stubs(:output_pipe).returns(UI)
    end

    it 'prints the version of CocoaPods as its first message' do
      command = Command::IPC::Repl.new(CLAide::ARGV.new([]))
      command.stubs(:listen)
      command.run

      out = UI.output
      out.should.match /version: '#{Pod::VERSION}'/
    end

    it 'forwards the commands to the other ipc subcommands and prints the result to STDOUT' do
      command = Command::IPC::Repl.new(CLAide::ARGV.new([]))
      command.execute_repl_command("podfile #{fixture('Podfile')}")

      out = UI.output
      out.should.include('---')
      out.should.match /target_definitions:/
      out.should.match /platform: ios/
      out.should.match /- SSZipArchive:/
      out.should.end_with?("\n\r\n")
    end
  end
end
