require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Command::IPC::UpdateSearchIndex do
    before do
      Command::IPC::UpdateSearchIndex.any_instance.stubs(:output_pipe).returns(UI)
    end

    it 'updates the search index and prints its path to STDOUT' do
      config.sources_manager.expects(:updated_search_index)
      out = run_command('ipc', 'update-search-index')
      out.should.include(config.sources_manager.search_index_path.to_s)
    end
  end
end
