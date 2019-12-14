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

CDN_REPO_RESPONSE = '---
            min: 1.0.0
            last: 1.8.1
            prefix_lengths:
            - 1
            - 1
            - 1'.freeze

def stub_url_as_cdn(url)
  WebMock.stub_request(:get, url + '/CocoaPods-version.yml').
    to_return(:status => 200, :headers => {}, :body => CDN_REPO_RESPONSE)
end

def stub_as_404(url)
  WebMock.stub_request(:get, url + '/CocoaPods-version.yml').
    to_return(:status => 404, :headers => {}, :body => '')
end

module Pod
  describe Source::Manager do
    extend SpecHelper::TemporaryRepos
    before do
      WebMock.reset!
      @test_source = Source.new(fixture('spec-repos/test_repo'))
      @sources_manager = Source::Manager.new(config.repos_dir)
      stub_url_as_cdn('https://cdn.cocoapods.org')
      stub_url_as_cdn('http://cdn.cocoapods.org')
    end

    after do
      WebMock.reset!
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

          it 'runs `pod repo add-cdn` when there is no matching source for CocoaPods Trunk' do
            Command::Repo::AddCDN.any_instance.stubs(:run).once
            @sources_manager.stubs(:source_with_url).returns(nil).then.returns(TrunkSource.new('trunk'))
            @sources_manager.find_or_create_source_with_url(Pod::TrunkSource::TRUNK_REPO_URL).name.
              should == 'trunk'
          end

          it 'runs `pod repo add` when there is no matching source' do
            Command::Repo::Add.any_instance.stubs(:run).once
            stub_as_404('https://github.com/artsy/Specs.git')
            @sources_manager.stubs(:source_with_url).returns(nil).then.returns(Source.new('Source'))
            @sources_manager.find_or_create_source_with_url('https://github.com/artsy/Specs.git').name.
              should == 'Source'
          end

          it 'runs `pod repo add` when the url doesn\'t end in `.git`' do
            Command::Repo::Add.any_instance.stubs(:run).once
            stub_as_404('https://github.com/artsy/Specs')
            @sources_manager.stubs(:source_with_url).returns(nil).then.returns(Source.new('Source'))
            @sources_manager.find_or_create_source_with_url('https://github.com/artsy/Specs').name.
              should == 'Source'
          end

          it 'runs `pod repo add-cdn` when there is no matching source and url is web' do
            Command::Repo::AddCDN.any_instance.stubs(:run).once
            stub_url_as_cdn('https://website.com/Specs')
            @sources_manager.stubs(:source_with_url).returns(nil).then.returns(Source.new('Source'))
            @sources_manager.find_or_create_source_with_url('https://website.com/Specs').name.
              should == 'Source'
          end

          it 'raises informative exception on network error' do
            Typhoeus.stubs(:get).with do
              raise StandardError, 'some network error'
            end
            @sources_manager.stubs(:source_with_url).returns(nil)
            should.raise(Informative) do
              @sources_manager.cdn_url?('https://website.com/Specs')
            end.message.should.include "Couldn't determine repo type for URL: `https://website.com/Specs`: some network error"
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
            stub_as_404('https://github.com/artsy/Specs.git')
            @sources_manager.stubs(:source_with_url).returns(nil).then.returns('Source')
            @sources_manager.source_with_name_or_url('https://github.com/artsy/Specs.git').
              should == 'Source'
          end
        end
      end

      describe '#add_source' do
        it 'adds the source to the list of sources' do
          source = Source.new(fixture('spec-repos/test_repo1'))
          @sources_manager.add_source(source)
          @sources_manager.all.should == [@test_source, source]
        end
      end

      describe 'detect cdn repo' do
        it 'cdn master spec repo' do
          @sources_manager.cdn_url?('https://cdn.cocoapods.org').should == true
        end

        it 'cdn master spec repo by http' do
          @sources_manager.cdn_url?('http://cdn.cocoapods.org').should == true
        end

        it 'git master spec repo' do
          stub_as_404('https://github.com/cocoapods/specs.git')
          stub_as_404('https://github.com/cocoapods/specs')
          @sources_manager.cdn_url?('https://github.com/cocoapods/specs.git').should == false
          @sources_manager.cdn_url?('https://github.com/cocoapods/specs').should == false
        end

        it 'fake 200 response' do
          HTML_RESPONSE = '<!doctype html>
          <html>
           <head>
            <title>Some page</title>\n\n <meta charset=\"utf-8\" />
           <body>
            <div>
             <h1>Some page</h1>
            </div>
           </body>
           </html>"'.freeze
          WebMock.stub_request(:get, 'https://some_host.com/something/CocoaPods-version.yml').
            to_return(:status => 200, :body => HTML_RESPONSE)
          @sources_manager.cdn_url?('https://some_host.com/something').should == false
        end

        it 'redirect' do
          WebMock.stub_request(:get, 'http://some_host.com/something/CocoaPods-version.yml').
            to_return(:status => 301, :body => '', :headers => { 'Location' => ['http://some_host.com'] })
          @sources_manager.cdn_url?('http://some_host.com/something').should == false
        end
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Updating Sources' do
      extend SpecHelper::TemporaryRepos

      before do
        Source.any_instance.stubs(:unchanged_github_repo?).returns(false)
      end

      it 'updates source backed by a git repository' do
        set_up_test_repo_for_update
        @sources_manager.expects(:update_search_index_if_needed_in_background).with({}).returns(nil)

        repo_update = sequence('repo update')
        Source.any_instance.
          expects(:git!).
          with(%W(-C #{test_repo_path} fetch origin --progress)).
          in_sequence(repo_update)

        Source.any_instance.
          expects(:git!).
          with(%W(-C #{test_repo_path} rev-parse --abbrev-ref HEAD)).
          returns("my-special-branch\n").
          in_sequence(repo_update)

        Source.any_instance.
          expects(:git!).
          with(%W(-C #{test_repo_path} reset --hard origin/my-special-branch)).
          in_sequence(repo_update)

        @sources_manager.update(test_repo_path.basename.to_s, true)
      end

      it 'updates source with --silent flag' do
        set_up_test_repo_for_update
        @sources_manager.expects(:update_search_index_if_needed_in_background).with({}).returns(nil)

        repo_update = sequence('repo update --silent')
        Source.any_instance.
          expects(:git!).
          with(%W(-C #{test_repo_path} fetch origin)).
          in_sequence(repo_update)

        Source.any_instance.
          expects(:git!).
          with(%W(-C #{test_repo_path} rev-parse --abbrev-ref HEAD)).
          returns("my-special-branch\n").
          in_sequence(repo_update)

        Source.any_instance.
          expects(:git!).
          with(%W(-C #{test_repo_path} reset --hard origin/my-special-branch)).
          in_sequence(repo_update)

        @sources_manager.update(test_repo_path.basename.to_s, false)
      end

      it 'prints a warning if the update failed' do
        set_up_test_repo_for_update
        Source.any_instance.stubs(:git).with do |options|
          options.join(' ') == %W(-C #{test_repo_path} rev-parse HEAD).join(' ')
        end.returns('aabbccd')
        Source.any_instance.stubs(:git).with do |options|
          options.join(' ') == %W(-C #{test_repo_path} diff --name-only aabbccd..HEAD).join(' ')
        end.returns('')
        Source.any_instance.expects(:git!).with(%W(-C #{test_repo_path} fetch origin --progress)).raises(<<-EOS)
fatal: '/dev/null' does not appear to be a git repository
fatal: Could not read from remote repository.

Please make sure you have the correct access rights
and the repository exists.
        EOS
        e = lambda { @sources_manager.update(test_repo_path.basename.to_s, true) }.should.raise Pod::Informative
        e.message.should.include('not able to update the `master` repo')
      end

      it 'informs the user if there is an update for CocoaPods' do
        master = Pod::TrunkSource.new(repo_path('trunk'))
        master.stubs(:metadata).returns(Source::Metadata.new('last' => '999.0'))
        master.verify_compatibility!
        UI.output.should.match /CocoaPods 999.0 is available/
      end

      it 'skips the update message if the user disabled the notification' do
        config.new_version_message = false
        master = Pod::TrunkSource.new(repo_path('trunk'))
        master.stubs(:metadata).returns(Source::Metadata.new('last' => '999.0'))
        master.verify_compatibility!
        UI.output.should.not.match /CocoaPods 999.0 is available/
      end

      it 'does not crash if the repos dir does not exist' do
        sources_manager = Source::Manager.new(Pathname.new(Dir.tmpdir) + 'CocoaPods/RepoDir/DoesNotExist')
        lambda { sources_manager.update }.should.not.raise
      end
    end
  end
end
