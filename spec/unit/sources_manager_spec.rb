require File.expand_path('../../spec_helper', __FILE__)
require 'webmock'

def set_up_test_repo_for_update
  set_up_test_repo
  upstream = SpecHelper.temporary_directory + 'upstream'
  FileUtils.cp_r(test_repo_path, upstream)
  Dir.chdir(test_repo_path) do
    `git remote add origin #{upstream}`
    `git remote -v`
    `git fetch -q`
    `git branch --set-upstream-to=origin/master master`
    `git config branch.master.rebase true`
  end
  @sources_manager.stubs(:repos_dir).returns(SpecHelper.tmp_repos_path)
end

module Pod
  describe Source::Manager do
    before do
      @test_source = Source.new(fixture('spec-repos/test_repo'))
      @sources_manager = Source::Manager.new(config.repos_dir)
    end

    #-------------------------------------------------------------------------#

    describe 'In general' do
      before do
        @sources_manager.stubs(:all).returns([@test_source])
      end

      #--------------------------------------#

      it 'returns the path of the search index' do
        Source::Manager.any_instance.unstub(:search_index_path)
        config.cache_root = Config::DEFAULTS[:cache_root]
        path = @sources_manager.search_index_path.to_s
        path.should.end_with 'Library/Caches/CocoaPods/search_index.json'
      end

      describe 'managing sources by URL' do
        describe 'finding or creating a source by URL' do
          it 'returns an existing matching source' do
            Source.any_instance.stubs(:url).returns('url')
            @sources_manager.expects(:name_for_url).never
            @sources_manager.find_or_create_source_with_url('url').url.
              should == 'url'
          end

          it 'runs `pod repo add` when there is no matching source' do
            Command::Repo::Add.any_instance.stubs(:run).once
            @sources_manager.stubs(:source_with_url).returns(nil).then.returns(Source.new('Source'))
            @sources_manager.find_or_create_source_with_url('https://github.com/artsy/Specs.git').name.
              should == 'Source'
          end

          it 'handles repositories without a remote url' do # for #2965
            Command::Repo::Add.any_instance.stubs(:run).once
            Source.any_instance.stubs(:url).returns(nil).then.returns('URL')
            @sources_manager.find_or_create_source_with_url('URL').url.should == 'URL'
          end
        end

        describe 'finding or creating a source by name or URL' do
          it 'returns an existing source with a matching name' do
            @sources_manager.expects(:name_for_url).never
            @sources_manager.source_with_name_or_url('test_repo').name.
              should == 'test_repo'
          end

          it 'tries by url when there is no matching name' do
            Command::Repo::Add.any_instance.stubs(:run).once
            @sources_manager.stubs(:source_with_url).returns(nil).then.returns('Source')
            @sources_manager.source_with_name_or_url('https://github.com/artsy/Specs.git').
              should == 'Source'
          end
        end
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Updating Sources' do
      extend SpecHelper::TemporaryRepos

      before do
        MasterSource.any_instance.stubs(:requires_update?).returns(true)
      end

      it 'updates source backed by a git repository' do
        set_up_test_repo_for_update
        @sources_manager.expects(:update_search_index_if_needed_in_background).with({}).returns(nil)
        MasterSource.any_instance.expects(:git!).with do |options|
          options.join(' ') == %W(-C #{test_repo_path} pull --ff-only).join(' ')
        end
        @sources_manager.update(test_repo_path.basename.to_s, true)
      end

      it 'uses the only fast forward git option' do
        set_up_test_repo_for_update
        MasterSource.any_instance.expects(:git!).with { |options| options.should.include? '--ff-only' }
        @sources_manager.expects(:update_search_index_if_needed_in_background).with({}).returns(nil)
        @sources_manager.update(test_repo_path.basename.to_s, true)
      end

      it 'unshallows if the git repo is shallow' do
        set_up_test_repo_for_update
        test_repo_path.join('.git', 'shallow').open('w') { |f| f << 'a' * 40 }
        @sources_manager.expects(:update_search_index_if_needed_in_background).with({}).returns(nil)
        MasterSource.any_instance.expects(:git!).with do |options|
          options.join(' ') == %W(-C #{test_repo_path} fetch --unshallow).join(' ')
        end
        MasterSource.any_instance.expects(:git!).with do |options|
          options.join(' ') == %W(-C #{test_repo_path} pull --ff-only).join(' ')
        end
        @sources_manager.update(test_repo_path.basename.to_s, true)

        UI.output.should.match /deep fetch.+`master`.+improve future performance/
      end

      it 'prints a warning if the update failed' do
        set_up_test_repo_for_update
        Source.any_instance.stubs(:git).with do |options|
          options.join(' ') == %W(-C #{test_repo_path} rev-parse HEAD).join(' ')
        end.returns('aabbccd')
        Source.any_instance.stubs(:git).with do |options|
          options.join(' ') == %W(-C #{test_repo_path} diff --name-only aabbccd..HEAD).join(' ')
        end.returns('')
        MasterSource.any_instance.expects(:git!).with do |options|
          options.join(' ') == %W(-C #{test_repo_path} pull --ff-only).join(' ')
        end.raises(<<-EOS)
fatal: '/dev/null' does not appear to be a git repository
fatal: Could not read from remote repository.

Please make sure you have the correct access rights
and the repository exists.
        EOS
        @sources_manager.expects(:update_search_index_if_needed_in_background).with({}).returns(nil)
        @sources_manager.update(test_repo_path.basename.to_s, true)
        UI.warnings.should.include('not able to update the `master` repo')
      end

      it 'informs the user if there is an update for CocoaPods' do
        master = @sources_manager.master.first
        master.stubs(:metadata).returns(Source::Metadata.new('last' => '999.0'))
        master.verify_compatibility!
        UI.output.should.match /CocoaPods 999.0 is available/
      end

      it 'skips the update message if the user disabled the notification' do
        config.new_version_message = false
        master = @sources_manager.master.first
        master.stubs(:metadata).returns(Source::Metadata.new('last' => '999.0'))
        master.verify_compatibility!
        UI.output.should.not.match /CocoaPods 999.0 is available/
      end
    end
  end
end
