require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Command::IPC::PodfileJSON do
    before do
      Command::IPC::PodfileJSON.any_instance.stubs(:output_pipe).returns(UI)
    end

    it 'converts a Podfile to JSON and prints it to STDOUT' do
      out = run_command('ipc', 'podfile-json', fixture('Podfile'))
      parsed_hash = JSON.parse(out)
      parsed_hash.should == { 'target_definitions' => [{ 'name' => 'Pods', 'abstract' => true, 'platform' => 'ios', 'dependencies' => [{ 'SSZipArchive' => ['>= 1'] }, { 'ASIHTTPRequest' => ['~> 1.8.0'] }, 'Reachability', { 'ASIWebPageRequest' => ['< 1.8.2'] }] }] }
    end
  end
end
