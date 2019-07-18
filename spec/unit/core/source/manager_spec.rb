require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Source::Manager do
    extend SpecHelper::TemporaryDirectory

    before do
      @test_source = Source.new(fixture('spec-repos-core/test_repo'))
      @sources_manager = Source::Manager.new(fixture('spec-repos-core'))
      @sources_manager.search_index_path = SpecHelper.temporary_directory + 'search_index.json'
    end

    after do
      test_cdn_repo_local_path = fixture('spec-repos-core/test_cdn_repo_local')
      Pathname.glob(test_cdn_repo_local_path.join('*')).each(&:rmtree)
    end

    #-------------------------------------------------------------------------#

    describe 'In general' do
      it 'does not fail if the repos directory does not exist' do
        @sources_manager.stubs(:repos_dir).returns(Pathname.new('/foo/bar'))
        @sources_manager.aggregate.sources.should == []
        @sources_manager.all.should == []
      end

      it 'returns all the sources' do
        @sources_manager.all.map(&:name).should == %w(artsy test_cdn_repo_local test_empty_dir_repo test_prefixed_repo test_repo test_repo_without_specs_dir trunk)
      end

      it 'includes all sources in an aggregate for a dependency if no source is specified' do
        dependency = Dependency.new('JSONKit', '1.4')
        aggregate = @sources_manager.aggregate_for_dependency(dependency)
        aggregate.sources.map(&:name).should == %w(artsy test_cdn_repo_local test_empty_dir_repo test_prefixed_repo test_repo test_repo_without_specs_dir trunk)
      end

      it 'includes all sources in an aggregate for a dependency if non-existent source is specified' do
        dependency = Dependency.new('JSONKit', '1.4', :source => 'https://url/to/nonexistent/specs.git')
        aggregate = @sources_manager.aggregate_for_dependency(dependency)
        aggregate.sources.map(&:name).should == %w(artsy test_cdn_repo_local test_empty_dir_repo test_prefixed_repo test_repo test_repo_without_specs_dir trunk)
      end

      it 'includes only the one source in an aggregate for a dependency if a source is specified' do
        repo_url = 'https://url/to/specs.git'
        dependency = Dependency.new('JSONKit', '1.4', :source => repo_url)

        source = mock
        source.stubs(:name).returns('repo')
        source.stubs(:repo).returns('path')

        @sources_manager.expects(:source_with_url).with(repo_url).returns(source)
        @sources_manager.expects(:source_from_path).with('path').returns(source)

        aggregate = @sources_manager.aggregate_for_dependency(dependency)
        aggregate.sources.map(&:name).should == [source.name]
      end

      it 'searches for the set of a dependency' do
        set = @sources_manager.search(Dependency.new('BananaLib'))
        set.class.should == Specification::Set
        set.name.should == 'BananaLib'
      end

      it 'returns nil if it is not able to find a pod for the given dependency' do
        set = @sources_manager.search(Dependency.new('Windows-Lib'))
        set.should.be.nil
      end

      it 'searches sets by name' do
        sets = @sources_manager.search_by_name('BananaLib')
        sets.all? { |s| s.class == Specification::Set }.should.be.true
        sets.any? { |s| s.name == 'BananaLib' }.should.be.true
      end

      it 'can perform a full text search of the sets' do
        @sources_manager.stubs(:all).returns([@test_source])
        sets = @sources_manager.search_by_name('Chunky', true)
        sets.all? { |s| s.class == Specification::Set }.should.be.true
        sets.any? { |s| s.name == 'BananaLib' }.should.be.true
      end

      it 'can perform a full text regexp search of the sets' do
        @sources_manager.stubs(:all).returns([@test_source])
        sets = @sources_manager.search_by_name('Ch[aeiou]nky', true)
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
          sets = @sources_manager.sorted_sets(@test_search_results, regexps)
          sets[0].name.should == 'Networking'
        end

        it 'puts pod with less prefix length before pods with more prefix length in search results' do
          regexps = [/reachability/i]
          sets = @sources_manager.sorted_sets(@test_search_results, regexps)
          sets.index { |s| s.name == 'AVReachability' }.should.be < sets.index { |s| s.name == 'VCLReachability' }
        end

        it 'puts pod with more query word match before pods with less match in multi word query search results' do
          regexps = [/network/i, /reachability/i]
          sets = @sources_manager.sorted_sets(@test_search_results, regexps)
          sets.index { |s| s.name == 'SCNetworkReachability' }.should.be < sets.index { |s| s.name == 'AVReachability' }
        end

        it 'puts pod matching first query word before pods matching later words in multi word query search results' do
          regexps = [/network/i, /reachability/i]
          sets = @sources_manager.sorted_sets(@test_search_results, regexps)
          sets.index { |s| s.name == 'PYNetwork' }.should.be < sets.index { |s| s.name == 'AVReachability' }
        end

        it 'puts pod matching first query word before pods matching later words in multi word query search results' do
          regexps = [/network/i, /reachability/i]
          sets = @sources_manager.sorted_sets(@test_search_results, regexps)
          sets.index { |s| s.name == 'PYNetwork' }.should.be < sets.index { |s| s.name == 'AVReachability' }
        end

        it 'alphabetically sorts pods having exact other conditions' do
          regexps = [/reachability/i]
          sets = @sources_manager.sorted_sets(@test_search_results, regexps)
          sets.index { |s| s.name == 'AVReachability' }.should.be < sets.index { |s| s.name == 'NPReachability' }
        end

        it 'alphabetically sorts pods whose names does not match query' do
          regexps = [/reachability/i]
          sets = @sources_manager.sorted_sets(@test_search_results, regexps)
          sets.index { |s| s.name == 'DLSuit' }.should.be < sets.index { |s| s.name == 'HockeyKit' }
        end
      end

      it 'deletes the search index file if it is invalid' do
        @sources_manager.save_search_index(nil)
        @sources_manager.stored_search_index.should.be.nil
        @sources_manager.search_index_path.exist?.should.be.false
      end

      it "generates the search index before performing a search if it doesn't exist" do
        @sources_manager.stubs(:all).returns([@test_source])
        Source::Aggregate.any_instance.expects(:generate_search_index_for_source).with(@test_source).returns('BananaLib' => ['BananaLib'])
        @sources_manager.updated_search_index = nil
        @sources_manager.search_by_name('BananaLib', true)
      end

      describe 'managing sources by URL' do
        describe 'generating a repo name from a URL' do
          it 'uses `trunk` for the CDN CocoaPods repository' do
            url = 'https://cdn.cocoapods.org/'
            Pathname.any_instance.stubs(:exist?).
              returns(false).then.returns(true)
            @sources_manager.send(:name_for_url, url).should == 'trunk'
          end

          it 'uses `trunk` for the CDN CocoaPods repository without a slash' do
            url = 'https://cdn.cocoapods.org'
            Pathname.any_instance.stubs(:exist?).
              returns(false).then.returns(true)
            @sources_manager.send(:name_for_url, url).should == 'trunk'
          end

          it 'uses the organization name for github.com URLs' do
            url = 'https://github.com/segiddins/banana.git'
            @sources_manager.send(:name_for_url, url).should == 'segiddins'
          end

          it 'uses a combination of host and path for other URLs' do
            url = 'https://sourceforge.org/Artsy/Specs.git'
            @sources_manager.send(:name_for_url, url).
              should == 'sourceforge-artsy-specs'
          end

          it 'supports scp-style URLs' do
            url = 'git@git-host.com:specs.git'
            @sources_manager.send(:name_for_url, url).
              should == 'git-host-specs'

            url = 'git@git-host.com/specs.git'
            @sources_manager.send(:name_for_url, url).
              should == 'git-host-specs'

            url = 'git@git-host.com:/specs.git'
            @sources_manager.send(:name_for_url, url).
              should == 'git-host-specs'
          end

          it 'supports ssh URLs with an aliased hostname' do
            url = 'ssh://user@companyalias/pod-specs'
            @sources_manager.send(:name_for_url, url).
              should == 'companyalias-pod-specs'
          end

          it 'supports file URLs' do
            url = 'file:///Users/kurrytran/pod-specs'
            @sources_manager.send(:name_for_url, url).
              should == 'users-kurrytran-pod-specs'
          end

          it 'uses the repo name if no parent directory' do
            url = 'file:///pod-specs'
            @sources_manager.send(:name_for_url, url).
              should == 'pod-specs'
          end

          it 'supports ssh URLs with no user component' do
            url = 'ssh://company.com/pods/specs.git'
            @sources_manager.send(:name_for_url, url).
              should == 'company-pods-specs'
          end

          it 'appends a number to the name if the base name dir exists' do
            url = 'https://github.com/segiddins/banana.git'
            Pathname.any_instance.stubs(:exist?).
              returns(true).then.returns(false)
            @sources_manager.send(:name_for_url, url).should == 'segiddins-1'

            url = 'https://sourceforge.org/Artsy/Specs.git'
            Pathname.any_instance.stubs(:exist?).
              returns(true).then.returns(false)
            @sources_manager.send(:name_for_url, url).
              should == 'sourceforge-artsy-specs-1'
          end
        end

        describe '#source_with_url' do
          it 'should find CDN with trailing slash' do
            @sources_manager.send(:source_with_url, 'https://cdn.cocoapods.org/').name.should == 'trunk'
          end

          it 'should find CDN without trailing slash' do
            @sources_manager.send(:source_with_url, 'https://cdn.cocoapods.org').name.should == 'trunk'
          end
        end
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Updating Sources' do
      before do
        Source.any_instance.stubs(:unchanged_github_repo?).returns(false)
      end

      it 'updates search index for changed paths if source is updated' do
        prev_index = { @test_source.name => { 'Banana' => %w(SOME_POD), 'NON_EXISTING_WORD' => %w(SOME_POD JSONKit BananaLib) } }
        @sources_manager.expects(:stored_search_index).returns(prev_index)

        @sources_manager.expects(:save_search_index).with do |value|
          value[@test_source.name]['BananaLib'].should.include('BananaLib')
          value[@test_source.name]['JSONKit'].should.include('JSONKit')
          value[@test_source.name]['Banana'].should.include('SOME_POD')
          value[@test_source.name]['Banana'].should.include('BananaLib')
          value[@test_source.name]['NON_EXISTING_WORD'].should.not.include('JSONKit')
          value[@test_source.name]['NON_EXISTING_WORD'].should.not.include('BananaLib')
          value[@test_source.name]['NON_EXISTING_WORD'].should.include('SOME_POD')
        end
        changed_paths = { @test_source => %w(Specs/BananaLib/1.0/BananaLib.podspec Specs/JSONKit/1.4/JSONKit.podspec) }
        @sources_manager.update_search_index_if_needed(changed_paths)
      end

      it 'does not update search index if it does not contain source even if there are changes in source' do
        prev_index = {}
        @sources_manager.expects(:stored_search_index).returns(prev_index)

        @sources_manager.expects(:save_search_index).with do |value|
          value[@test_source.name].should.be.nil
        end
        changed_paths = { @test_source => %w(Specs/BananaLib/1.0/BananaLib.podspec Specs/JSONKit/1.4/JSONKit.podspec) }
        @sources_manager.update_search_index_if_needed(changed_paths)
      end

      it 'process fork is called when updating search index in background' do
        Process.expects(:fork)

        changed_paths = { @test_source => %w(Specs/BananaLib/1.0/BananaLib.podspec Specs/JSONKit/1.4/JSONKit.podspec) }
        @sources_manager.update_search_index_if_needed_in_background(changed_paths)
      end

      it 'process fork is not called when updating search index in background on Windows' do
        Gem.stubs(:win_platform?).returns(true)
        Process.stubs(:fork).at_most(0)

        changed_paths = { @test_source => %w(Specs/BananaLib/1.0/BananaLib.podspec Specs/JSONKit/1.4/JSONKit.podspec) }
        @sources_manager.update_search_index_if_needed_in_background(changed_paths)
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Master repo' do
      it 'returns the master repo dir' do
        @sources_manager.master_repo_dir.to_s.should.match %r{fixtures/spec-repos-core/trunk}
      end

      it 'returns an empty array for master sources when the master repo has not been set up' do
        Pathname.any_instance.stubs(:directory?).returns(false)
        @sources_manager.master.should == []
      end

      it 'returns whether the master repo is functional' do
        @sources_manager.master_repo_functional?.should.be.true
        @sources_manager.stubs(:repos_dir).returns(SpecHelper.temporary_directory)
        @sources_manager.master_repo_functional?.should.be.false
      end
    end
  end
end
