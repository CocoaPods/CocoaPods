require File.expand_path('../spec_helper', __FILE__)

module Pod
  describe GitHub do
    describe 'In general' do
      it 'returns the information of a user' do
        VCR.use_cassette('GitHub', :record => :new_episodes) do
          user = GitHub.user('CocoaPods')
          user['login'].should == 'CocoaPods'
        end
      end

      it 'returns the information of a repo' do
        VCR.use_cassette('GitHub', :record => :new_episodes) do
          repo = GitHub.repo('https://github.com/CocoaPods/CocoaPods')
          repo['name'].should == 'CocoaPods'
        end
      end

      it 'handles SSH as well as HTTP' do
        VCR.use_cassette('GitHub', :record => :new_episodes) do
          repo = GitHub.repo('git@github.com:CocoaPods/CocoaPods')
          repo['name'].should == 'CocoaPods'
        end
      end

      it 'strips any trailing .git suffix' do
        VCR.use_cassette('GitHub', :record => :new_episodes) do
          repo = GitHub.repo('git@github.com:CocoaPods/CocoaPods.git')
          repo['name'].should == 'CocoaPods'
        end
      end

      it 'returns the information of a repo with dots in the name' do
        VCR.use_cassette('GitHub', :record => :new_episodes) do
          repo = GitHub.repo('https://github.com/contentful/contentful.objc')
          repo['name'].should == 'contentful.objc'
        end
      end

      it 'returns the tags of a repo' do
        VCR.use_cassette('GitHub', :record => :new_episodes) do
          tags = GitHub.tags('https://github.com/CocoaPods/CocoaPods')
          tags.find { |t| t['name'] == '0.20.2' }.should.not.be.nil
        end
      end

      it 'returns the branches of a repo' do
        VCR.use_cassette('GitHub', :record => :new_episodes) do
          branches = GitHub.branches('https://github.com/CocoaPods/CocoaPods')
          branches.find { |t| t['name'] == 'master' }.should.not.be.nil
        end
      end

      it 'returns the contents of a repo' do
        VCR.use_cassette('GitHub', :record => :new_episodes) do
          contents = GitHub.contents('https://github.com/CocoaPods/CocoaPods')
          contents.find { |t| t['name'] == 'README.md' }.should.not.be.nil
        end
      end

      it 'returns the modified state of a repo' do
        VCR.use_cassette('GitHub', :record => :new_episodes) do
          old_commit_updated = GitHub.modified_since_commit('https://github.com/CocoaPods/CocoaPods', '6a0ba68e4f0c0229b46f311687cfc81209efd5b9')
          old_commit_updated.should.be.true

          latest_commit_updated = GitHub.modified_since_commit('https://github.com/CocoaPods/CocoaPods', '436c0e2f71bd2c129ef607a40d57068e6f31ceb7')
          latest_commit_updated.should.be.false
        end
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Additional behaviour' do
      it 'sets the user agent' do
        VCR.use_cassette('GitHub', :record => :new_episodes) do
          url = 'https://api.github.com/repos/CocoaPods/CocoaPods'
          headers = { 'User-Agent' => 'CocoaPods' }
          response = stub(:body => '{}', :ok? => true)
          REST.expects(:get).with(url, headers).returns(response)
          GitHub.repo('http://github.com/CocoaPods/CocoaPods')
        end
      end

      it 'supports URLs with the `http` protocol' do
        VCR.use_cassette('GitHub', :record => :new_episodes) do
          repo = GitHub.repo('http://github.com/CocoaPods/CocoaPods')
          repo['name'].should == 'CocoaPods'
        end
      end

      it 'supports the GitHub identifier instead of the URL' do
        VCR.use_cassette('GitHub', :record => :new_episodes) do
          repo = GitHub.repo('CocoaPods/CocoaPods')
          repo['name'].should == 'CocoaPods'
        end
      end

      it 'returns nil if a requests fails' do
        VCR.use_cassette('GitHub', :record => :new_episodes) do
          repo = GitHub.repo('https://github.com/CocoaPods/Missing_Repo')
          repo.should.be.nil
        end
      end

      it 'prints a warning for failed requests' do
        VCR.use_cassette('GitHub', :record => :new_episodes) do
          GitHub.repo('https://github.com/CocoaPods/Missing_Repo')
          CoreUI.warnings.should.match /Request to https:.*Missing_Repo failed - 404/
          CoreUI.warnings.should.match /Not Found/
        end
      end

      #-----------------------------------------------------------------------#
    end
  end
end
