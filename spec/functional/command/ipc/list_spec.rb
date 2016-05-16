require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Command::IPC::List do
    before do
      Command::IPC::List.any_instance.stubs(:output_pipe).returns(UI)
    end

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
end
