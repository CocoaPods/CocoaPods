require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Command::IPC::Podfile do
    before do
      Command::IPC::Podfile.any_instance.stubs(:output_pipe).returns(UI)
    end

    it 'converts a Podfile to yaml and prints it to STDOUT' do
      out = run_command('ipc', 'podfile', fixture('Podfile'))
      out.should.include('---')
      out.should.match /target_definitions:/
      out.should.match /platform: ios/
      out.should.match /- SSZipArchive:/
    end
  end
end
