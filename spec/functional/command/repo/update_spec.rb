require File.expand_path('../../../../spec_helper', __FILE__)
require 'webmock'

module Pod
  describe Command::Repo::Update do
    extend SpecHelper::Command
    extend SpecHelper::TemporaryRepos

    before do
      set_up_test_repo
      config.repos_dir = SpecHelper.tmp_repos_path

      MasterSource.any_instance.stubs(:git_commit_hash).returns('commit hash')
      WebMock.stub_request(:get, 'https://api.github.com/repos/CocoaPods/Specs/commits/master').
        with(:headers => { 'Accept' => 'application/vnd.github.chitauri-preview+sha', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'If-None-Match' => '"commit hash"', 'User-Agent' => 'CocoaPods' }).
        to_return(:status => 200, :body => '', :headers => {})
    end

    after do
      WebMock.reset!
    end

    it 'updates a repository' do
      upstream = SpecHelper.temporary_directory + 'upstream'
      FileUtils.cp_r(test_repo_path, upstream)
      Dir.chdir(test_repo_path) do
        `git remote add origin #{upstream}`
        `git remote -v`
        `git fetch -q`
        `git branch --set-upstream-to=origin/master master`
      end
      config.sources_manager.expects(:update_search_index_if_needed_in_background).with({}).returns(nil)
      lambda { command('repo', 'update').run }.should.not.raise
    end

    it 'updates a spec-repo' do
      repo1 = repo_make('repo1')
      repo2 = repo_clone('repo1', 'repo2')
      repo_make_readme_change(repo1, 'Updated')
      Dir.chdir(repo1) { `git commit -a -m "Update"` }
      config.sources_manager.expects(:update_search_index_if_needed_in_background).with do |value|
        value.each_pair do |source, paths|
          source.name.should == 'repo2'
          paths.should == ['README']
        end
      end
      run_command('repo', 'update', 'repo2')
      (repo2 + 'README').read.should.include 'Updated'
    end
  end
end
