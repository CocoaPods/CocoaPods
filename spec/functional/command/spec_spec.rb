require File.expand_path('../../../spec_helper', __FILE__)

# README!
#
# Adds {Command::Spec::Edit#exec} to fake the {Kernel#exec} call that would
# normally be made during an edit.
#
module Pod
  class Command
    class Spec
      class Edit
        def exec(cmd, *args)
          UI.puts "#{cmd} #{args.join(' ')}"
          raise SystemExit
        end
      end
    end
  end
end

module Pod
  describe Command::Spec do
    describe 'In general' do
      it 'complains for wrong parameters' do
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

    describe 'create subcommand' do
      extend SpecHelper::TemporaryRepos

      it 'creates a new podspec stub file' do
        run_command('spec', 'create', 'Bananas')
        path = temporary_directory + 'Bananas.podspec'
        spec = Specification.from_file(path)

        spec.name.should == 'Bananas'
        spec.license.should == { :type => 'MIT (example)' }
        spec.version.should == Version.new('0.0.1')
        spec.summary.should == 'A short description of Bananas.'
        spec.homepage.should == 'http://EXAMPLE/Bananas'
        spec.authors.should == { `git config --get user.name`.strip => `git config --get user.email`.strip }
        spec.source.should == { :git => 'http://EXAMPLE/Bananas.git', :tag => '0.0.1' }
        spec.consumer(:ios).source_files.should == ['Classes', 'Classes/**/*.{h,m}']
        spec.consumer(:ios).public_header_files.should == []
      end

      it 'correctly creates a podspec from github' do
        repo = {
          'name' => 'libPusher',
          'owner' => { 'login' => 'lukeredpath' },
          'html_url' => 'https://github.com/lukeredpath/libPusher',
          'description' => 'An Objective-C interface to Pusher (pusherapp.com)',
          'clone_url' => 'https://github.com/lukeredpath/libPusher.git',
        }
        GitHub.expects(:repo).with('lukeredpath/libPusher').returns(repo)
        GitHub.expects(:tags).with('https://github.com/lukeredpath/libPusher').returns([{ 'name' => 'v1.4' }])
        GitHub.expects(:user).with('lukeredpath').returns('name' => 'Luke Redpath', 'email' => 'luke@lukeredpath.co.uk')
        run_command('spec', 'create', 'https://github.com/lukeredpath/libPusher.git')
        path = temporary_directory + 'libPusher.podspec'
        spec = Specification.from_file(path)
        spec.name.should == 'libPusher'
        spec.license.should == { :type => 'MIT (example)' }
        spec.version.should == Version.new('1.4')
        spec.summary.should == 'An Objective-C interface to Pusher (pusherapp.com)'
        spec.homepage.should == 'https://github.com/lukeredpath/libPusher'
        spec.authors.should == { 'Luke Redpath' => 'luke@lukeredpath.co.uk' }
        spec.source.should == { :git => 'https://github.com/lukeredpath/libPusher.git', :tag => 'v1.4' }
      end

      it 'accepts a name when creating a podspec form github' do
        repo = {
          'name' => 'libPusher',
          'owner' => { 'login' => 'lukeredpath' },
          'html_url' => 'https://github.com/lukeredpath/libPusher',
          'description' => 'An Objective-C interface to Pusher (pusherapp.com)',
          'clone_url' => 'https://github.com/lukeredpath/libPusher.git',
        }
        GitHub.expects(:repo).with('lukeredpath/libPusher').returns(repo)
        GitHub.expects(:tags).with('https://github.com/lukeredpath/libPusher').returns([{ 'name' => 'v1.4' }])
        GitHub.expects(:user).with('lukeredpath').returns('name' => 'Luke Redpath', 'email' => 'luke@lukeredpath.co.uk')
        run_command('spec', 'create', 'other_name', 'https://github.com/lukeredpath/libPusher.git')
        path = temporary_directory + 'other_name.podspec'
        spec = Specification.from_file(path)
        spec.name.should == 'other_name'
        spec.homepage.should == 'https://github.com/lukeredpath/libPusher'
      end

      it 'correctly suggests the head commit if a suitable tag is not available on github' do
        repo = {
          'name' => 'libPusher',
          'owner' => { 'login' => 'lukeredpath' },
          'html_url' => 'https://github.com/lukeredpath/libPusher',
          'description' => 'An Objective-C interface to Pusher (pusherapp.com)',
          'clone_url' => 'https://github.com/lukeredpath/libPusher.git',
        }
        GitHub.expects(:repo).with('lukeredpath/libPusher').returns(repo)
        GitHub.expects(:tags).with('https://github.com/lukeredpath/libPusher').returns([{ 'name' => 'experiment' }])
        GitHub.expects(:branches).with('https://github.com/lukeredpath/libPusher').returns([{ 'name' => 'master', 'commit' => { 'sha' => '5f482b0693ac2ac1ad85d1aabc27ec7547cc0bc7' } }])
        GitHub.expects(:user).with('lukeredpath').returns('name' => 'Luke Redpath', 'email' => 'luke@lukeredpath.co.uk')
        run_command('spec', 'create', 'https://github.com/lukeredpath/libPusher.git')
        path = temporary_directory + 'libPusher.podspec'
        spec = Specification.from_file(path)
        spec.version.should == Version.new('0.0.1')
        spec.source.should == { :git => 'https://github.com/lukeredpath/libPusher.git', :commit => '5f482b0693ac2ac1ad85d1aabc27ec7547cc0bc7' }
      end

      it 'correctly reuses version variable in source if matching tag is found on github' do
        repo = {
          'name' => 'libPusher',
          'owner' => { 'login' => 'lukeredpath' },
          'html_url' => 'https://github.com/lukeredpath/libPusher',
          'description' => 'An Objective-C interface to Pusher (pusherapp.com)',
          'clone_url' => 'https://github.com/lukeredpath/libPusher.git',
        }
        GitHub.expects(:repo).with('lukeredpath/libPusher').returns(repo)
        GitHub.expects(:tags).with('https://github.com/lukeredpath/libPusher').returns([{ 'name' => '1.4.0' }])
        GitHub.expects(:user).with('lukeredpath').returns('name' => 'Luke Redpath', 'email' => 'luke@lukeredpath.co.uk')
        run_command('spec', 'create', 'https://github.com/lukeredpath/libPusher.git')
        path = temporary_directory + 'libPusher.podspec'
        spec = Specification.from_file(path)
        spec.version.should == Version.new('1.4.0')
        spec.source.should == { :git => 'https://github.com/lukeredpath/libPusher.git', :tag => '1.4.0' }
        File.open(path, 'r') { |f| f.read.should.include ':tag => "#{s.version}"' }
      end

      it 'correctly reuses version variable in source if matching tag with prefix is found on github' do
        repo = {
          'name' => 'libPusher',
          'owner' => { 'login' => 'lukeredpath' },
          'html_url' => 'https://github.com/lukeredpath/libPusher',
          'description' => 'An Objective-C interface to Pusher (pusherapp.com)',
          'clone_url' => 'https://github.com/lukeredpath/libPusher.git',
        }
        GitHub.expects(:repo).with('lukeredpath/libPusher').returns(repo)
        GitHub.expects(:tags).with('https://github.com/lukeredpath/libPusher').returns([{ 'name' => 'v1.4.0' }])
        GitHub.expects(:user).with('lukeredpath').returns('name' => 'Luke Redpath', 'email' => 'luke@lukeredpath.co.uk')
        run_command('spec', 'create', 'https://github.com/lukeredpath/libPusher.git')
        path = temporary_directory + 'libPusher.podspec'
        spec = Specification.from_file(path)
        spec.version.should == Version.new('1.4.0')
        spec.source.should == { :git => 'https://github.com/lukeredpath/libPusher.git', :tag => 'v1.4.0' }
        File.open(path, 'r') { |f| f.read.should.include ':tag => "v#{s.version}"' }
      end

      it "raises an informative message when the GitHub repository doesn't have any commits" do
        repo = {
          'name' => 'QueryKit',
          'owner' => { 'login' => 'QueryKit' },
          'html_url' => 'https://github.com/QueryKit/QueryKit',
          'description' => 'A simple CoreData query language for Swift and Objective-C.',
          'clone_url' => 'https://github.com/QueryKit/QueryKit.git',
        }
        GitHub.expects(:repo).with('QueryKit/QueryKit').returns(repo)
        GitHub.expects(:tags).with('https://github.com/QueryKit/QueryKit').returns([])
        GitHub.expects(:branches).with('https://github.com/QueryKit/QueryKit').returns([])
        GitHub.expects(:user).with('QueryKit').returns('name' => 'QueryKit', 'email' => 'support@querykit.org')

        e = lambda do
          run_command('spec', 'create', 'https://github.com/QueryKit/QueryKit.git')
        end.should.raise Pod::Informative
        e.message.should.match(/Unable to find.*commits.*master branch/)
      end

      it "provides a markdown template if a github repo doesn't have semantic version tags" do
        repo = {
          'name' => 'libPusher',
          'owner' => { 'login' => 'lukeredpath' },
          'html_url' => 'https://github.com/lukeredpath/libPusher',
          'description' => 'An Objective-C interface to Pusher (pusherapp.com)',
          'clone_url' => 'https://github.com/lukeredpath/libPusher.git',
        }
        GitHub.expects(:repo).with('lukeredpath/libPusher').returns(repo)
        GitHub.expects(:tags).with('https://github.com/lukeredpath/libPusher').returns([{ 'name' => 'experiment' }])
        GitHub.expects(:branches).with('https://github.com/lukeredpath/libPusher').returns([{ 'name' => 'master', 'commit' => { 'sha' => '5f482b0693ac2ac1ad85d1aabc27ec7547cc0bc7' } }])
        GitHub.expects(:user).with('lukeredpath').returns('name' => 'Luke Redpath', 'email' => 'luke@lukeredpath.co.uk')
        output = run_command('spec', 'create', 'https://github.com/lukeredpath/libPusher.git')
        output.should.include 'MARKDOWN TEMPLATE'
        output.should.include 'Please add semantic version tags'
      end
    end

    #-------------------------------------------------------------------------#

    describe Command::Spec::Lint do
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

      it 'lints the current working directory' do
        Dir.chdir(fixture('spec-repos') + 'master/Specs/1/3/f/JSONKit/1.4/') do
          cmd = command('spec', 'lint', '--quick', '--allow-warnings')
          cmd.run
          UI.output.should.include 'passed validation'
        end
      end

      it 'fails with an informative error when downloading the podspec 404s' do
        WebMock.stub_request(:get, 'https://no.such.domain/404').
          to_return(:status => 404, :body => '', :headers => {})
        lambda { run_command('spec', 'lint', 'https://no.such.domain/404') }.should.raise Informative, /404/
      end

      before do
        text = (fixture('spec-repos') + 'master/Specs/1/3/f/JSONKit/1.4/JSONKit.podspec.json').read
        text.gsub!(/.*license.*/, '"license": { "file": "LICENSE" },')
        file = temporary_directory + 'JSONKit.podspec.json'
        File.open(file, 'w') { |f| f.write(text) }
        @spec_path = file.to_s
      end

      it 'lints a given podspec' do
        cmd = command('spec', 'lint', '--quick', @spec_path)
        exception = lambda { cmd.run }.should.raise Informative
        UI.output.should.include 'Missing license type'
        exception.message.should.match /due to 1 warning /
        exception.message.should.match /use `--allow-warnings` to ignore it\)/
      end

      it 'respects the --allow-warnings option' do
        cmd = command('spec', 'lint', '--quick', '--allow-warnings', @spec_path)
        lambda { cmd.run }.should.not.raise
        UI.output.should.include 'Missing license type'
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
      it 'complains provided spec name is ambigious' do
        e = lambda { command('spec', command, 'AF').run }.should.raise Informative
        e.message.should.match /More than one/
      end
    end

    def describe_regex_support(command, raise_class = nil)
      describe 'RegEx support' do
        before do
          @test_source = Source.new(fixture('spec-repos/test_repo'))
          Source::Aggregate.any_instance.stubs(:sources).returns([@test_source])
          config.sources_manager.updated_search_index = nil
          yield if block_given?
        end

        it 'raise when using an invalid regex' do
          lambda { run_command('spec', command, '--regex', '+') }.should.raise CLAide::Help
        end

        it 'does not try to validate the query as a regex with plain-text mode' do
          l = lambda { run_command('spec', command, '+') }
          if raise_class
            l.should.raise raise_class
          else
            l.should.not.raise CLAide::Help
          end
        end

        it 'uses regex search when asked for regex mode' do
          l = lambda { run_command('spec', command, '--regex', 'Ba(na)+Lib') }
          if raise_class
            l.should.raise raise_class
          else
            l.should.not.raise
          end
          UI.output.should.include? 'BananaLib'
          UI.output.should.not.include? 'Pod+With+Plus+Signs'
          UI.output.should.not.include? 'JSONKit'
        end

        it 'uses plain-text search when not asked for regex mode' do
          l = lambda { run_command('spec', command, 'Pod+With+Plus+Signs') }
          if raise_class
            l.should.raise raise_class
          else
            l.should.not.raise
          end
          UI.output.should.include? 'Pod+With+Plus+Signs'
          UI.output.should.not.include? 'BananaLib'
        end
      end
    end

    describe Command::Spec::Which do
      it_should_check_for_existence('which')
      it_should_check_for_ambiguity('which')

      it 'prints the path of a given podspec' do
        lambda { command('spec', 'which', 'AFNetworking').run }.should.not.raise
        text = 'AFNetworking.podspec'
        UI.output.should.include text.gsub(/\n/, '')
      end

      describe_regex_support('which')
    end

    #-------------------------------------------------------------------------#

    describe Command::Spec::Cat do
      it_should_check_for_existence('cat')
      it_should_check_for_ambiguity('cat')

      it 'cats the given podspec' do
        lambda { command('spec', 'cat', 'AFNetworking').run }.should.not.raise
        UI.output.should.include fixture('spec-repos/master/Specs/a/7/5/AFNetworking/3.1.0/AFNetworking.podspec.json').read
      end

      it 'cats the first podspec from all podspecs' do
        UI.next_input = "1\n"
        run_command('spec', 'cat', '--show-all', 'AFNetworking')
        UI.output.should.include fixture('spec-repos/master/Specs/a/7/5/AFNetworking/3.1.0/AFNetworking.podspec.json').read
      end

      describe_regex_support('cat')
    end

    #-------------------------------------------------------------------------#

    describe Command::Spec::Edit do
      before do
        @path_saved = ENV['PATH']
      end

      after do
        ENV['PATH'] = @path_saved
      end

      it_should_check_for_existence('edit')
      it_should_check_for_ambiguity('edit')

      it 'would execute the editor specified in ENV with the given podspec' do
        ENV['EDITOR'] = 'podspeceditor'
        lambda { command('spec', 'edit', 'AFNetworking').run }.should.raise SystemExit
        UI.output.should.include '/bin/sh -i -c podspeceditor "$@" --'
        UI.output.should.include 'fixtures/spec-repos/master/Specs/a/7/5/AFNetworking'
      end

      it 'will raise if no editor is found' do
        ENV['PATH'] = ''
        ENV['EDITOR'] = nil
        lambda { command('spec', 'edit', 'AFNetworking').run }.should.raise Informative
      end

      it 'would execute an editor with the first podspec from all podspecs' do
        ENV['EDITOR'] = 'podspeceditor'
        UI.next_input = "1\n"
        lambda { command('spec', 'edit', '--show-all', 'AFNetworking').run }.should.raise SystemExit
        UI.output.should.include '/bin/sh -i -c podspeceditor "$@" --'
        UI.output.should.include 'fixtures/spec-repos/master/Specs/a/7/5/AFNetworking/1.2.0/AFNetworking.podspec'
      end

      it "complains if it can't find a spec file for the given spec" do
        File.stubs(:exist?).returns(false)
        lambda { command('spec', 'edit', 'AFNetworking').run }.should.raise Informative
        File.unstub(:exists?)
      end

      describe_regex_support('edit', SystemExit) { ENV['EDITOR'] = 'podspeceditor' }
    end

    #-------------------------------------------------------------------------#

    describe 'Private helpers' do
      before do
        # TODO: Use class methods
        @command = Command::Spec.new(CLAide::ARGV.new([]))
      end

      describe '#get_path_of_spec' do
        it 'returns the path of the specification with the given name' do
          path = @command.send(:get_path_of_spec, 'AFNetworking')
          path.should == fixture('spec-repos') + 'master/Specs/a/7/5/AFNetworking/3.1.0/AFNetworking.podspec.json'
        end
      end
    end

    #-------------------------------------------------------------------------#
  end
end
