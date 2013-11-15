require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::Spec do

    describe "In general" do

      it "complains for wrong parameters" do
        lambda { run_command('spec') }.should.raise CLAide::Help
        lambda { run_command('spec', 'create') }.should.raise CLAide::Help
        lambda { run_command('spec', '--create') }.should.raise CLAide::Help
        lambda { run_command('spec', 'NAME') }.should.raise CLAide::Help
        lambda { run_command('spec', 'createa') }.should.raise CLAide::Help
        lambda { run_command('lint', 'agument1', '2') }.should.raise CLAide::Help
        lambda { run_command('spec', 'which') }.should.raise CLAide::Help
        lambda { run_command('spec', 'cat') }.should.raise CLAide::Help
        lambda { run_command('spec', 'edit') }.should.raise CLAide::Help
        lambda { run_command('spec', 'browse') }.should.raise CLAide::Help
      end
    end

    #-------------------------------------------------------------------------#

    describe "create subcommand" do
      extend SpecHelper::TemporaryRepos

      it "creates a new podspec stub file" do
        run_command('spec', 'create', 'Bananas')
        path = temporary_directory + 'Bananas.podspec'
        spec = Specification.from_file(path)

        spec.name.should         == 'Bananas'
        spec.license.should      == { :type => "MIT (example)" }
        spec.version.should      == Version.new('0.0.1')
        spec.summary.should      == 'A short description of Bananas.'
        spec.homepage.should     == 'http://EXAMPLE/Bananas'
        spec.authors.should      == { `git config --get user.name`.strip => `git config --get user.email`.strip}
        spec.source.should       == { :git => 'http://EXAMPLE/Bananas.git', :tag => '0.0.1' }
        spec.consumer(:ios).source_files.should == ['Classes', 'Classes/**/*.{h,m}']
        spec.consumer(:ios).public_header_files.should == []
      end

      it "correctly creates a podspec from github" do
        repo = {
          'name' => 'libPusher',
          'owner' => { 'login' => 'lukeredpath' },
          'html_url' => 'https://github.com/lukeredpath/libPusher',
          'description' => 'An Objective-C interface to Pusher (pusherapp.com)',
          'clone_url' => 'https://github.com/lukeredpath/libPusher.git'
        }
        GitHub.expects(:repo).with('lukeredpath/libPusher').returns(repo)
        GitHub.expects(:tags).with('https://github.com/lukeredpath/libPusher').returns([{"name"=>"v1.4"}])
        GitHub.expects(:user).with('lukeredpath').returns({ "name" => "Luke Redpath", "email" => "luke@lukeredpath.co.uk" })
        run_command('spec', 'create', 'https://github.com/lukeredpath/libPusher.git')
        path = temporary_directory + 'libPusher.podspec'
        spec = Specification.from_file(path)
        spec.name.should     == 'libPusher'
        spec.license.should  == { :type => "MIT (example)" }
        spec.version.should  == Version.new('1.4')
        spec.summary.should  == 'An Objective-C interface to Pusher (pusherapp.com)'
        spec.homepage.should == 'https://github.com/lukeredpath/libPusher'
        spec.authors.should  == {"Luke Redpath"=>"luke@lukeredpath.co.uk"}
        spec.source.should   == { :git => 'https://github.com/lukeredpath/libPusher.git', :tag => 'v1.4' }
      end

      it "accepts a name when creating a podspec form github" do
        repo = {
          'name' => 'libPusher',
          'owner' => { 'login' => 'lukeredpath' },
          'html_url' => 'https://github.com/lukeredpath/libPusher',
          'description' => 'An Objective-C interface to Pusher (pusherapp.com)',
          'clone_url' => 'https://github.com/lukeredpath/libPusher.git'
        }
        GitHub.expects(:repo).with('lukeredpath/libPusher').returns(repo)
        GitHub.expects(:tags).with('https://github.com/lukeredpath/libPusher').returns([{"name"=>"v1.4"}])
        GitHub.expects(:user).with('lukeredpath').returns({ "name" => "Luke Redpath", "email" => "luke@lukeredpath.co.uk" })
        run_command('spec', 'create', 'other_name', 'https://github.com/lukeredpath/libPusher.git')
        path = temporary_directory + 'other_name.podspec'
        spec = Specification.from_file(path)
        spec.name.should     == 'other_name'
        spec.homepage.should == 'https://github.com/lukeredpath/libPusher'
      end

      it "correctly suggests the head commit if a suitable tag is not available on github" do
        repo = {
          'name' => 'libPusher',
          'owner' => { 'login' => 'lukeredpath' },
          'html_url' => 'https://github.com/lukeredpath/libPusher',
          'description' => 'An Objective-C interface to Pusher (pusherapp.com)',
          'clone_url' => 'https://github.com/lukeredpath/libPusher.git'
        }
        GitHub.expects(:repo).with('lukeredpath/libPusher').returns(repo)
        GitHub.expects(:tags).with('https://github.com/lukeredpath/libPusher').returns([{"name"=>"experiment"}])
        GitHub.expects(:branches).with('https://github.com/lukeredpath/libPusher').returns([{"name"=>"master", "commit" => {'sha' => '5f482b0693ac2ac1ad85d1aabc27ec7547cc0bc7'}}])
        GitHub.expects(:user).with('lukeredpath').returns({ "name" => "Luke Redpath", "email" => "luke@lukeredpath.co.uk" })
        run_command('spec', 'create', 'https://github.com/lukeredpath/libPusher.git')
        path = temporary_directory + 'libPusher.podspec'
        spec = Specification.from_file(path)
        spec.version.should == Version.new('0.0.1')
        spec.source.should  == { :git => 'https://github.com/lukeredpath/libPusher.git', :commit => '5f482b0693ac2ac1ad85d1aabc27ec7547cc0bc7' }
      end

      it "provides a markdown template if a github repo doesn't have semantic version tags" do
        repo = {
          'name' => 'libPusher',
          'owner' => { 'login' => 'lukeredpath' },
          'html_url' => 'https://github.com/lukeredpath/libPusher',
          'description' => 'An Objective-C interface to Pusher (pusherapp.com)',
          'clone_url' => 'https://github.com/lukeredpath/libPusher.git'
        }
        GitHub.expects(:repo).with('lukeredpath/libPusher').returns(repo)
        GitHub.expects(:tags).with('https://github.com/lukeredpath/libPusher').returns([{"name"=>"experiment"}])
        GitHub.expects(:branches).with('https://github.com/lukeredpath/libPusher').returns([{"name"=>"master", "commit" => {'sha' => '5f482b0693ac2ac1ad85d1aabc27ec7547cc0bc7'}}])
        GitHub.expects(:user).with('lukeredpath').returns({ "name" => "Luke Redpath", "email" => "luke@lukeredpath.co.uk" })
        output = run_command('spec', 'create', 'https://github.com/lukeredpath/libPusher.git')
        output.should.include 'MARKDOWN TEMPLATE'
        output.should.include 'Please add semantic version tags'
      end
    end

    #-------------------------------------------------------------------------#

    describe "lint subcommand" do
      extend SpecHelper::TemporaryRepos

      it "complains if it can't find any spec to lint" do
        Dir.chdir(temporary_directory) do
          lambda { command('spec', 'lint').run }.should.raise Informative
        end
      end

      it "complains if it can't find a spec with the given name" do
        Dir.chdir(temporary_directory) do
          lambda { run_command('spec', 'lint', 'some_pod_that_doesnt_exist') }.should.raise Informative
        end
      end

      it "lints the current working directory" do
        Dir.chdir(fixture('spec-repos') + 'master/JSONKit/1.4/') do
          cmd = command('spec', 'lint', '--quick', '--only-errors')
          cmd.run
          UI.output.should.include "passed validation"
        end
      end

      # @todo VCR is required in CocoaPods only for this test.
      xit "lints a remote podspec" do
        Dir.chdir(fixture('spec-repos') + 'master/JSONKit/1.4/') do
          cmd = command('spec', 'lint', '--quick', '--only-errors', '--silent', 'https://github.com/CocoaPods/Specs/raw/master/A2DynamicDelegate/2.0.1/A2DynamicDelegate.podspec')
          # VCR.use_cassette('linter', :record => :new_episodes) {  }
          lambda { cmd.run }.should.not.raise
        end
      end

      before do
        text = (fixture('spec-repos') + 'master/JSONKit/1.4/JSONKit.podspec').read
        text.gsub!(/.*license.*/, "s.license = { :file => 'some_file'}")
        file = temporary_directory + 'JSONKit.podspec'
        File.open(file, 'w') {|f| f.write(text) }
        @spec_path = file.to_s
      end

      it "lints a given podspec" do
        cmd = command('spec', 'lint', '--quick', @spec_path)
        lambda { cmd.run }.should.raise Informative
        UI.output.should.include "Missing license type"
      end

      it "respects the -only--errors option" do
        cmd = command('spec', 'lint', '--quick', '--only-errors', @spec_path)
        lambda { cmd.run }.should.not.raise
        UI.output.should.include "Missing license type"
      end
    end

    #-------------------------------------------------------------------------#

    def it_should_check_for_existence(command)
      it "errors if a given podspec doesn't exist" do
        e = lambda { command('spec', command, 'some_pod_that_doesnt_exist').run }.should.raise Informative
        e.message.should.match /Unable to find a pod with/
      end
    end

    def it_should_check_for_ambiguity(command)
      it "complains provided spec name is ambigious" do
        e = lambda { command('spec', command, 'AF').run }.should.raise Informative
        e.message.should.match /More than one/
      end
    end

    describe Command::Spec::Which do
      it_should_check_for_existence("which")
      it_should_check_for_ambiguity("which")

      it "prints the path of a given podspec" do
        lambda { command('spec', 'which', 'AFNetworking').run }.should.not.raise
        text = "AFNetworking.podspec"
        UI.output.should.include text.gsub(/\n/, '')
      end
    end

    #-------------------------------------------------------------------------#

    describe Command::Spec::Cat do
      it_should_check_for_existence("cat")
      it_should_check_for_ambiguity("cat")
    end

    #-------------------------------------------------------------------------#

    describe Command::Spec::Edit do
      it_should_check_for_existence("edit")
      it_should_check_for_ambiguity("edit")
    end

    #-------------------------------------------------------------------------#

    describe "Private helpers" do

      describe "#get_path_of_spec" do

        before do
          # TODO Use class methods
          @sut = Command::Spec.new(CLAide::ARGV.new([]))

        end

        it "returns the path of the specification with the given name" do
          path = @sut.send(:get_path_of_spec, 'AFNetworking')
          path.should == fixture('spec-repos') + 'master/AFNetworking/1.2.0/AFNetworking.podspec'
        end

      end

    end

    #-------------------------------------------------------------------------#

  end
end

