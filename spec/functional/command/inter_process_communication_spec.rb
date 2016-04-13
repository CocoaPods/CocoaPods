require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::IPC do
    before do
      Command::IPC::Spec.any_instance.stubs(:output_pipe).returns(UI)
      Command::IPC::Podfile.any_instance.stubs(:output_pipe).returns(UI)
      Command::IPC::List.any_instance.stubs(:output_pipe).returns(UI)
      Command::IPC::UpdateSearchIndex.any_instance.stubs(:output_pipe).returns(UI)
      Command::IPC::Repl.any_instance.stubs(:output_pipe).returns(UI)
    end

    describe Command::IPC::Spec do
      it 'converts a podspec to JSON and prints it to STDOUT' do
        out = run_command('ipc', 'spec', fixture('banana-lib/BananaLib.podspec'))
        out.should.match /"name": "BananaLib"/
        out.should.match /"version": "1.0"/
        out.should.match /"description": "Full of chunky bananas."/
      end
    end

    #-------------------------------------------------------------------------#

    describe Command::IPC::Podfile do
      it 'converts a Podfile to yaml and prints it to STDOUT' do
        out = run_command('ipc', 'podfile', fixture('Podfile'))
        out.should.include('---')
        out.should.match /target_definitions:/
        out.should.match /platform: ios/
        out.should.match /- SSZipArchive:/
      end
    end

    #-------------------------------------------------------------------------#

    describe Command::IPC::List do
      it 'prints a list of podspecs in the yaml format and prints it to STDOUT' do
        spec = fixture_spec('banana-lib/BananaLib.podspec')
        set = Specification::Set.new('BananaLib', [])
        set.stubs(:specification).returns(spec)
        Source::Aggregate.any_instance.stubs(:all_sets).returns([set])

        out = run_command('ipc', 'list')
        out.should.include('---')
        out.should.match /BananaLib:/
        out.should.match /description: Full of chunky bananas./
      end
    end

    #-------------------------------------------------------------------------#

    describe Command::IPC::UpdateSearchIndex do
      it 'updates the search index and prints its path to STDOUT' do
        config.sources_manager.expects(:updated_search_index)
        out = run_command('ipc', 'update-search-index')
        out.should.include(config.sources_manager.search_index_path.to_s)
      end
    end

    #-------------------------------------------------------------------------#

    describe Command::IPC::Repl do
      it 'prints the version of CocoaPods as its first message' do
        command = Command::IPC::Repl.new(CLAide::ARGV.new([]))
        command.stubs(:listen)
        command.run

        out = UI.output
        out.should.match /version: '#{Pod::VERSION}'/
      end

      it 'converts forwards the commands to the other ipc subcommands prints the result to STDOUT' do
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

    #-------------------------------------------------------------------------#
  end
end
