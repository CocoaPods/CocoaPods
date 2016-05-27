require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Command::IPC::Spec do
    before do
      Command::IPC::Spec.any_instance.stubs(:output_pipe).returns(UI)
    end

    it 'converts a podspec to JSON and prints it to STDOUT' do
      out = run_command('ipc', 'spec', fixture('banana-lib/BananaLib.podspec'))
      out.should.match /"name": "BananaLib"/
      out.should.match /"version": "1.0"/
      out.should.match /"description": "Full of chunky bananas."/
    end
  end
end
