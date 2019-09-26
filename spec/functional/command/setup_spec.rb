require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::Setup do
    extend SpecHelper::Command

    extend SpecHelper::TemporaryRepos

    before do
      config.repos_dir = SpecHelper.tmp_repos_path
    end

    it 'displays setup completed message' do
      UI.expects(:puts).with('Setup completed')
      run_command('setup')
    end
  end
end
