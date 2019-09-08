require File.expand_path('../../../../spec_helper', __FILE__)
require 'webmock'

module Pod
  describe Command::Repo::Update do
    extend SpecHelper::Command
    extend SpecHelper::TemporaryRepos

    before do
      set_up_test_repo
      config.repos_dir = SpecHelper.tmp_repos_path
    end

    it 'updates a repository' do
      upstream = SpecHelper.temporary_directory + 'upstream'
      FileUtils.cp_r(test_repo_path, upstream)
      Dir.chdir(test_repo_path) do
        Pod::Executable.capture_command!('git', %W(remote add origin #{upstream}))
        Pod::Executable.capture_command!('git', %w(remote -v))
        Pod::Executable.capture_command!('git', %w(fetch -q))
        Pod::Executable.capture_command!('git', %w(branch --set-upstream-to=origin/master master))
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

    # Conditionally skip the test if `tmutil` is not available.
    has_tmutil = system('tmutil', 'version', :out => File::NULL)
    cit = has_tmutil ? method(:it) : method(:xit)
    cit.call 'excludes the spec-repo from Time Machine backups' do
      repo_make('repo1')
      repo_clone('repo1', 'repo2')
      run_command('repo', 'update', 'repo2')
      `tmutil isexcluded #{config.repos_dir + 'repo2'}`.chomp.should.start_with?('[Excluded]')
    end

    it 'repo updates do not fail when executed in parallel' do
      repo1 = repo_make('repo1')
      repo_clone('repo1', 'repo2')
      repo_make_readme_change(repo1, 'Updated')
      Dir.chdir(repo1) { Pod::Executable.capture_command!('git', %w(commit -a -m Update)) }
      thread1 = Thread.new do
        lambda { command('repo', 'update', 'repo2').run }.should.not.raise
      end
      thread2 = Thread.new do
        lambda { command('repo', 'update', 'repo2').run }.should.not.raise
      end

      thread1.join
      thread2.join
    end
  end
end
