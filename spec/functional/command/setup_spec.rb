require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::Setup do
    extend SpecHelper::Command

    extend SpecHelper::TemporaryRepos

    before do
      config.repos_dir = SpecHelper.tmp_repos_path
    end

    it 'Displays deprecation notice' do
      UI.expects(:puts).never
      run_command('setup')
    end
  end
end
