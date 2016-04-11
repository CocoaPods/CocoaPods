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
  config.repos_dir = SpecHelper.tmp_repos_path
end

def merge_conflict_version_yaml
  <<-VERSION.strip_heredoc
    ---
    <<<<<<< HEAD
    min: 0.18.1
    =======
    min: 0.29.0
    >>>>>>> 8365d0ad18508175bbde31b9dd2bdaf1be49214f
    last: 0.29.0
  VERSION
end

module Pod
  describe SourcesManager do
    before do
      @test_source = Source.new(fixture('spec-repos/test_repo'))
    end

    #-------------------------------------------------------------------------#

    describe 'In general' do
      before do
        SourcesManager.stubs(:all).returns([@test_source])
      end

      #--------------------------------------#

      it 'does not fail if the repos directory does not exist' do
        config.stubs(:repos_dir).returns(Pathname.new('/foo/bar'))
        SourcesManager.unstub(:all)
        SourcesManager.aggregate.sources.should == []
        SourcesManager.all.should == []
      end

      it 'returns all the sources' do
        SourcesManager.unstub(:all)
        SourcesManager.all.map(&:name).should == %w(master test_repo)
      end

      it 'includes all sources in an aggregate for a dependency if no source is specified' do
        dependency = Dependency.new('JSONKit', '1.4')
        aggregate = SourcesManager.aggregate_for_dependency(dependency)
        aggregate.sources.map(&:name).should == %w(master test_repo)
      end

      it 'includes only the one source in an aggregate for a dependency if a source is specified' do
        repo_url = 'https://url/to/specs.git'
        dependency = Dependency.new('JSONKit', '1.4', :source => repo_url)

        source = mock
        source.stubs(:name).returns('repo')

        SourcesManager.expects(:source_with_url).with(repo_url).returns(source)

        aggregate = SourcesManager.aggregate_for_dependency(dependency)
        aggregate.sources.map(&:name).should == [source.name]
      end

      it 'searches for the set of a dependency' do
        set = SourcesManager.search(Dependency.new('BananaLib'))
        set.class.should == Specification::Set
        set.name.should == 'BananaLib'
      end

      it 'returns nil if it is not able to find a pod for the given dependency' do
        set = SourcesManager.search(Dependency.new('Windows-Lib'))
        set.should.be.nil
      end

      it 'searches sets by name' do
        sets = SourcesManager.search_by_name('BananaLib')
        sets.all? { |s| s.class == Specification::Set }.should.be.true
        sets.any? { |s| s.name == 'BananaLib' }.should.be.true
      end

      it 'can perform a full text search of the sets' do
        SourcesManager.stubs(:all).returns([@test_source])
        sets = SourcesManager.search_by_name('Chunky', true)
        sets.all? { |s| s.class == Specification::Set }.should.be.true
        sets.any? { |s| s.name == 'BananaLib' }.should.be.true
      end

      it 'can perform a full text regexp search of the sets' do
        SourcesManager.stubs(:all).returns([@test_source])
        sets = SourcesManager.search_by_name('Ch[aeiou]nky', true)
        sets.all? { |s| s.class == Specification::Set }.should.be.true
        sets.any? { |s| s.name == 'BananaLib' }.should.be.true
      end

      describe 'Sorting algorithm' do
        before do
          @test_search_results = %w(HockeyKit DLSuit VCLReachability NPReachability AVReachability PYNetwork
                                    SCNetworkReachability AFNetworking Networking).map do |name|
            Specification::Set.new(name)
          end
        end

        it 'puts pod with exact match at the first index while sorting' do
          regexps = [/networking/i]
          sets = SourcesManager.sorted_sets(@test_search_results, regexps)
          sets[0].name.should == 'Networking'
        end

        it 'puts pod with less prefix length before pods with more prefix length in search results' do
          regexps = [/reachability/i]
          sets = SourcesManager.sorted_sets(@test_search_results, regexps)
          sets.index { |s| s.name == 'AVReachability' }.should.be < sets.index { |s| s.name == 'VCLReachability' }
        end

        it 'puts pod with more query word match before pods with less match in multi word query search results' do
          regexps = [/network/i, /reachability/i]
          sets = SourcesManager.sorted_sets(@test_search_results, regexps)
          sets.index { |s| s.name == 'SCNetworkReachability' }.should.be < sets.index { |s| s.name == 'AVReachability' }
        end

        it 'puts pod matching first query word before pods matching later words in multi word query search results' do
          regexps = [/network/i, /reachability/i]
          sets = SourcesManager.sorted_sets(@test_search_results, regexps)
          sets.index { |s| s.name == 'PYNetwork' }.should.be < sets.index { |s| s.name == 'AVReachability' }
        end

        it 'puts pod matching first query word before pods matching later words in multi word query search results' do
          regexps = [/network/i, /reachability/i]
          sets = SourcesManager.sorted_sets(@test_search_results, regexps)
          sets.index { |s| s.name == 'PYNetwork' }.should.be < sets.index { |s| s.name == 'AVReachability' }
        end

        it 'alphabetically sorts pods having exact other conditions' do
          regexps = [/reachability/i]
          sets = SourcesManager.sorted_sets(@test_search_results, regexps)
          sets.index { |s| s.name == 'AVReachability' }.should.be < sets.index { |s| s.name == 'NPReachability' }
        end

        it 'alphabetically sorts pods whose names does not match query' do
          regexps = [/reachability/i]
          sets = SourcesManager.sorted_sets(@test_search_results, regexps)
          sets.index { |s| s.name == 'DLSuit' }.should.be < sets.index { |s| s.name == 'HockeyKit' }
        end
      end

      it "generates the search index before performing a search if it doesn't exist" do
        SourcesManager.stubs(:all).returns([@test_source])
        Source::Aggregate.any_instance.expects(:generate_search_index_for_source).with(@test_source).returns('BananaLib' => ['BananaLib'])
        SourcesManager.updated_search_index = nil
        SourcesManager.search_by_name('BananaLib', true)
      end

      it 'returns the path of the search index' do
        SourcesManager.unstub(:search_index_path)
        config.cache_root = Config::DEFAULTS[:cache_root]
        path = SourcesManager.search_index_path.to_s
        path.should.match %r{Library/Caches/CocoaPods/search_index.json}
      end

      describe 'managing sources by URL' do
        describe 'generating a repo name from a URL' do
          it 'uses `master` for the master CocoaPods repository' do
            url = 'https://github.com/CocoaPods/Specs.git'
            Pathname.any_instance.stubs(:exist?).
              returns(false).then.returns(true)
            SourcesManager.send(:name_for_url, url).should == 'master'

            url = 'git@github.com:CocoaPods/Specs.git'
            Pathname.any_instance.stubs(:exist?).
              returns(false).then.returns(true)
            SourcesManager.send(:name_for_url, url).should == 'master'

            url = 'git@github.com:/CocoaPods/Specs.git'
            Pathname.any_instance.stubs(:exist?).
              returns(false).then.returns(true)
            SourcesManager.send(:name_for_url, url).should == 'master'
          end

          it 'uses the organization name for github.com URLs' do
            url = 'https://github.com/segiddins/banana.git'
            SourcesManager.send(:name_for_url, url).should == 'segiddins'
          end

          it 'uses a combination of host and path for other URLs' do
            url = 'https://sourceforge.org/Artsy/Specs.git'
            SourcesManager.send(:name_for_url, url).
              should == 'sourceforge-artsy-specs'
          end

          it 'supports scp-style URLs' do
            url = 'git@git-host.com:specs.git'
            SourcesManager.send(:name_for_url, url).
              should == 'git-host-specs'

            url = 'git@git-host.com/specs.git'
            SourcesManager.send(:name_for_url, url).
              should == 'git-host-specs'

            url = 'git@git-host.com:/specs.git'
            SourcesManager.send(:name_for_url, url).
              should == 'git-host-specs'
          end

          it 'supports ssh URLs with an aliased hostname' do
            url = 'ssh://user@companyalias/pod-specs'
            SourcesManager.send(:name_for_url, url).
              should == 'companyalias-pod-specs'
          end

          it 'supports file URLs' do
            url = 'file:///Users/kurrytran/pod-specs'
            SourcesManager.send(:name_for_url, url).
              should == 'users-kurrytran-pod-specs'
          end

          it 'uses the repo name if no parent directory' do
            url = 'file:///pod-specs'
            SourcesManager.send(:name_for_url, url).
              should == 'pod-specs'
          end

          it 'supports ssh URLs with no user component' do
            url = 'ssh://company.com/pods/specs.git'
            SourcesManager.send(:name_for_url, url).
              should == 'company-pods-specs'
          end

          it 'appends a number to the name if the base name dir exists' do
            url = 'https://github.com/segiddins/banana.git'
            Pathname.any_instance.stubs(:exist?).
              returns(true).then.returns(false)
            SourcesManager.send(:name_for_url, url).should == 'segiddins-1'

            url = 'https://sourceforge.org/Artsy/Specs.git'
            Pathname.any_instance.stubs(:exist?).
              returns(true).then.returns(false)
            SourcesManager.send(:name_for_url, url).
              should == 'sourceforge-artsy-specs-1'
          end
        end

        describe 'finding or creating a source by URL' do
          it 'returns an existing matching source' do
            Source.any_instance.stubs(:url).returns('url')
            SourcesManager.expects(:name_for_url).never
            SourcesManager.find_or_create_source_with_url('url').url.
              should == 'url'
          end

          it 'runs `pod repo add` when there is no matching source' do
            Command::Repo::Add.any_instance.stubs(:run).once
            SourcesManager.stubs(:source_with_url).returns(nil).then.returns(Source.new('Source'))
            SourcesManager.find_or_create_source_with_url('https://github.com/artsy/Specs.git').name.
              should == 'Source'
          end

          it 'handles repositories without a remote url' do # for #2965
            Command::Repo::Add.any_instance.stubs(:run).once
            Source.any_instance.stubs(:url).returns(nil)
            e = lambda { SourcesManager.find_or_create_source_with_url('url') }
            e.should.not.raise
          end
        end

        describe 'finding or creating a source by name or URL' do
          it 'returns an existing source with a matching name' do
            SourcesManager.expects(:name_for_url).never
            SourcesManager.source_with_name_or_url('test_repo').name.
              should == 'test_repo'
          end

          it 'tries by url when there is no matching name' do
            Command::Repo::Add.any_instance.stubs(:run).once
            SourcesManager.stubs(:source_with_url).returns(nil).then.returns('Source')
            SourcesManager.source_with_name_or_url('https://github.com/artsy/Specs.git').
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
        SourcesManager.expects(:update_search_index_if_needed_in_background).with({}).returns(nil)
        MasterSource.any_instance.expects(:git!).with(%w(pull --ff-only))
        SourcesManager.update(test_repo_path.basename.to_s, true)
      end

      it 'uses the only fast forward git option' do
        set_up_test_repo_for_update
        MasterSource.any_instance.expects(:git!).with { |options| options.should.include? '--ff-only' }
        SourcesManager.expects(:update_search_index_if_needed_in_background).with({}).returns(nil)
        SourcesManager.update(test_repo_path.basename.to_s, true)
      end

      it 'unshallows if the git repo is shallow' do
        set_up_test_repo_for_update
        test_repo_path.join('.git', 'shallow').open('w') { |f| f << 'a' * 40 }
        SourcesManager.expects(:update_search_index_if_needed_in_background).with({}).returns(nil)
        MasterSource.any_instance.expects(:git!).with(%w(fetch --unshallow))
        MasterSource.any_instance.expects(:git!).with(%w(pull --ff-only))
        SourcesManager.update(test_repo_path.basename.to_s, true)

        UI.output.should.match /deep fetch.+`master`.+improve future performance/
      end

      it 'prints a warning if the update failed' do
        set_up_test_repo_for_update
        Source.any_instance.stubs(:git).with(%w(rev-parse HEAD)).returns('aabbccd')
        Source.any_instance.stubs(:git).with(%w(diff --name-only aabbccd..HEAD)).returns('')
        MasterSource.any_instance.expects(:git!).with(%w(pull --ff-only)).raises(<<-EOS)
fatal: '/dev/null' does not appear to be a git repository
fatal: Could not read from remote repository.

Please make sure you have the correct access rights
and the repository exists.
        EOS
        SourcesManager.expects(:update_search_index_if_needed_in_background).with({}).returns(nil)
        SourcesManager.update(test_repo_path.basename.to_s, true)
        UI.warnings.should.include('not able to update the `master` repo')
      end

      it 'updates search index for changed paths if source is updated' do
        prev_index = { @test_source.name => { 'Banana' => %w(SOME_POD), 'NON_EXISTING_WORD' => %w(SOME_POD JSONKit BananaLib) } }
        SourcesManager.expects(:stored_search_index).returns(prev_index)

        SourcesManager.expects(:save_search_index).with do |value|
          value[@test_source.name]['BananaLib'].should.include('BananaLib')
          value[@test_source.name]['JSONKit'].should.include('JSONKit')
          value[@test_source.name]['Banana'].should.include('SOME_POD')
          value[@test_source.name]['Banana'].should.include('BananaLib')
          value[@test_source.name]['NON_EXISTING_WORD'].should.not.include 'JSONKit'
          value[@test_source.name]['NON_EXISTING_WORD'].should.not.include 'BananaLib'
          value[@test_source.name]['NON_EXISTING_WORD'].should.include 'SOME_POD'
        end
        changed_paths = { @test_source => %w(BananaLib/1.0/BananaLib.podspec JSONKit/1.4/JSONKit.podspec) }
        SourcesManager.update_search_index_if_needed(changed_paths)
      end

      it 'does not update search index if it does not contain source even if there are changes in source' do
        prev_index = {}
        SourcesManager.expects(:stored_search_index).returns(prev_index)

        SourcesManager.expects(:save_search_index).with do |value|
          value[@test_source.name].should.be.nil
        end
        changed_paths = { @test_source => %w(BananaLib/1.0/BananaLib.podspec JSONKit/1.4/JSONKit.podspec) }
        SourcesManager.update_search_index_if_needed(changed_paths)
      end

      it 'returns whether a source is backed by a git repo' do
        SourcesManager.git_repo?(SourcesManager.master_repo_dir).should.be.true
        SourcesManager.git_repo?(Pathname.new('/tmp')).should.be.false
      end

      it 'informs the user if there is an update for CocoaPods' do
        SourcesManager.stubs(:version_information).returns('last' => '999.0')
        SourcesManager.check_version_information(temporary_directory)
        UI.output.should.match /CocoaPods 999.0 is available/
      end

      it 'recommends the user to use the latest stable version' do
        SourcesManager.stubs(:version_information).returns('last' => '999.0')
        SourcesManager.check_version_information(temporary_directory)
        UI.output.should.match /We strongly recommend that you use the/
      end

      it 'skips the update message if the user disabled the notification' do
        config.new_version_message = false
        SourcesManager.stubs(:version_information).returns('last' => '999.0')
        SourcesManager.check_version_information(temporary_directory)
        UI.output.should.not.match /CocoaPods 999.0 is available/
      end

      it 'raises while asked to version information of a source if it is not compatible' do
        SourcesManager.stubs(:version_information).returns('min' => '999.0')
        e = lambda { SourcesManager.check_version_information(temporary_directory) }.should.raise Informative
        e.message.should.match /Update CocoaPods/
        e.message.should.match /(currently using #{Pod::VERSION})/
        SourcesManager.stubs(:version_information).returns('max' => '0.0.1')
        e = lambda { SourcesManager.check_version_information(temporary_directory) }.should.raise Informative
        e.message.should.match /Update CocoaPods/
        e.message.should.match /(currently using #{Pod::VERSION})/
      end

      it 'raises when reading version information with merge conflict' do
        File.stubs(:read).returns(merge_conflict_version_yaml)
        e = lambda { SourcesManager.version_information(SourcesManager.master_repo_dir) }.should.raise Informative
        e.message.should.match /Repairing-Our-Broken-Specs-Repository/
      end

      it 'returns whether a path is writable' do
        path = '/Users/'
        Pathname.any_instance.stubs(:writable?).returns(true)
        SourcesManager.send(:path_writable?, path).should.be.true
      end

      it 'knows when sudo is needed' do
        SourcesManager.stubs(:path_writable?).returns(false)
        SourcesManager.send(:needs_sudo?).should.be.true
      end

      it 'knows when sudo is not needed' do
        SourcesManager.stubs(:path_writable?).returns(true)
        SourcesManager.send(:needs_sudo?).should.be.false
      end

      it 'returns whether a repository is compatible' do
        SourcesManager.stubs(:version_information).returns('min' => '0.0.1')
        SourcesManager.repo_compatible?('stub').should.be.true

        SourcesManager.stubs(:version_information).returns('max' => '999.0')
        SourcesManager.repo_compatible?('stub').should.be.true

        SourcesManager.stubs(:version_information).returns('min' => '999.0')
        SourcesManager.repo_compatible?('stub').should.be.false

        SourcesManager.stubs(:version_information).returns('max' => '0.0.1')
        SourcesManager.repo_compatible?('stub').should.be.false
      end

      it 'returns whether there is a CocoaPods update available' do
        SourcesManager.cocoapods_update?('last' => '0.0.1').should.be.false
        SourcesManager.cocoapods_update?('last' => '999.0').should.be.true
      end

      it "it returns an empty array for the version information if the file can't be found" do
        SourcesManager.version_information(temporary_directory).should == {}
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Master repo' do
      it 'returns the master repo dir' do
        SourcesManager.master_repo_dir.to_s.should.match %r{fixtures/spec-repos/master}
      end

      it 'returns an empty array for master sources when the master repo has not been set up' do
        Pathname.any_instance.stubs(:directory?).returns(false)
        SourcesManager.master.should == []
      end

      it 'returns whether the master repo is functional' do
        SourcesManager.master_repo_functional?.should.be.true
        config.repos_dir = SpecHelper.temporary_directory
        SourcesManager.master_repo_functional?.should.be.false
      end
    end
  end
end
