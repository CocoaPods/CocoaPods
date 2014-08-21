require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe 'Command::List' do
    extend SpecHelper::TemporaryRepos

    before do
      set_up_test_repo
      config.repos_dir = SpecHelper.tmp_repos_path
    end

    it 'presents the known pods' do
      out = run_command('list')
      [/BananaLib/,
       /JSONKit/,
       /\d+ pods were found/,
      ].each { |regex| out.should =~ regex }
    end

    it 'returns the new pods' do
      sets = SourcesManager.aggregate.all_sets
      jsonkit_set = sets.find { |s| s.name == 'JSONKit' }
      dates = {
        'BananaLib' => Time.now,
        'JSONKit'   => Time.parse('01/01/1970') }
      Specification::Set::Statistics.any_instance.stubs(:creation_dates).returns(dates)
      out = run_command('list', 'new')
      out.should.include('BananaLib')
      out.should.not.include('JSONKit')
    end

    it 'presents the known pods with versions' do
      sets = SourcesManager.aggregate.all_sets
      jsonkit_set = sets.find { |s| s.name == 'JSONKit' }

      out = run_command('list')
      [/BananaLib 1.0/,
       /JSONKit #{jsonkit_set.versions.first}/,
       /\d+ pods were found/,
      ].each { |regex| out.should =~ regex }
    end
  end
end
