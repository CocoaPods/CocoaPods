require File.expand_path('../../spec_helper', __FILE__)
require 'webmock'

module Pod
  describe Validator do
    before do
      WebMock.enable!
      WebMock.disable_net_connect!
    end

    after do
      WebMock.reset!
      WebMock.disable!
    end

    before do
      Validator.any_instance.stubs(:xcodebuild).returns('')
      Validator.any_instance.stubs(:xcodebuild_available?).returns(true)
    end

    # @return [void]
    #
    def write_podspec(text, name = 'JSONKit.podspec.json')
      file = temporary_directory + name
      File.open(file, 'w') { |f| f.write(text) }
      file
    end

    # @return [String]
    #
    def stub_podspec(pattern = nil, replacement = nil)
      spec = podspec_path.read
      spec.gsub!(/.*license.*$/, '"license": "Public Domain",')
      spec.gsub!(%r{https://github\.com/johnezang/JSONKit\.git}, fixture('integration/JSONKit').to_s)
      spec.gsub!(pattern, replacement) if pattern && replacement
      spec
    end

    # @return [Pathname]
    #
    def podspec_path(name = 'JSONKit', version = '1.4')
      Config.instance.sources_manager.master.first.pod_path(name).join("#{version}/#{name}.podspec.json")
    end

    #-------------------------------------------------------------------------#

    describe 'Quick mode' do
      it 'validates a correct podspec' do
        validator = Validator.new(podspec_path, config.sources_manager.master.map(&:url))
        validator.quick = true
        validator.validate
        validator.results.should == []
        validator.validated?.should.be.true
      end

      it 'lints the podspec during validation' do
        podspec = stub_podspec(/.*name.*/, '"name": "TEST",')
        file = write_podspec(podspec)
        validator = Validator.new(file, config.sources_manager.master.map(&:url))
        validator.quick = true
        validator.validate
        validator.results.map(&:to_s).first.should.match /should match the name/
        validator.validated?.should.be.false
      end

      it 'respects quick mode' do
        file = write_podspec(stub_podspec)
        validator = Validator.new(file, config.sources_manager.master.map(&:url))
        validator.quick = true
        validator.expects(:perform_extensive_analysis).never
        validator.validate
      end

      it 'respects the allow warnings option' do
        podspec = stub_podspec(/.*summary.*/, '"summary": "A short description of",')
        file = write_podspec(podspec)
        validator = Validator.new(file, config.sources_manager.master.map(&:url))
        validator.quick = true
        validator.allow_warnings = true
        validator.validate
        validator.results.map(&:to_s).first.should.match /summary.*meaningful/
        validator.validated?.should.be.true
      end

      it 'handles symlinks' do
        file = write_podspec(stub_podspec)
        validator = Validator.new(file, config.sources_manager.master.map(&:url))
        validator.quick = true
        validator.stubs(:validate_url)
        validator.validate
        validator.validated?.should.be.true
      end

      describe '#only_subspec' do
        before do
          podspec = podspec_path('RestKit', '0.22.0')
          @validator = Validator.new(podspec, config.sources_manager.master.map(&:url))
          @validator.quick = true
        end

        it 'handles a relative subspec name' do
          @validator.only_subspec = 'CoreData'
          @validator.validate
          @validator.send(:subspec_name).should == 'RestKit/CoreData'
        end

        it 'handles an absolute subspec name' do
          @validator.only_subspec = 'RestKit/CoreData'
          @validator.validate
          @validator.send(:subspec_name).should == 'RestKit/CoreData'
        end

        it 'handles a missing subspec name' do
          @validator.only_subspec = 'RestKit/Missing'
          should.raise(Informative) { @validator.validate }.message.
            should.include 'Unable to find a specification named `RestKit/Missing`'

          @validator.only_subspec = 'Missing'
          should.raise(Informative) { @validator.validate }.message.
            should.include 'Unable to find a specification named `RestKit/Missing`'
        end
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Extensive analysis' do
      describe 'URL validation' do
        before do
          @validator = Validator.new(podspec_path, config.sources_manager.master.map(&:url))
          @validator.stubs(:download_pod)
          @validator.stubs(:check_file_patterns)
          @validator.stubs(:install_pod)
          @validator.stubs(:add_app_project_import)
          @validator.stubs(:build_pod)
          @validator.stubs(:tear_down_validation_environment)
          @validator.stubs(:perform_linting)
          @validator.stubs(:validate_homepage)
          @validator.stubs(:validate_screenshots)
          @validator.stubs(:validate_social_media_url)
          @validator.stubs(:validate_documentation_url)
          @validator.stubs(:validate_source_url)
          @validator.stubs(:perform_extensive_subspec_analysis)
          Specification.any_instance.stubs(:available_platforms).returns([])

          WebMock::API.stub_request(:head, /not-found/).to_return(:status => 404)
          WebMock::API.stub_request(:get, /not-found/).to_return(:status => 404)
        end

        describe 'Homepage validation' do
          before do
            @validator.unstub(:validate_homepage)
          end

          it 'checks if the homepage is valid' do
            Specification.any_instance.stubs(:homepage).returns('http://banana-corp.local/not-found/')
            @validator.validate
            @validator.results.map(&:to_s).first.should.match /The URL (.*) is not reachable/
          end

          it 'indicates if it was not able to validate the homepage' do
            WebMock::API.stub_request(:head, 'banana-corp.local').to_raise(SocketError)
            Specification.any_instance.stubs(:homepage).returns('http://banana-corp.local/')
            @validator.validate
            @validator.results.map(&:to_s).first.should.match /There was a problem validating the URL/
          end

          it 'does not fail if the homepage redirects' do
            WebMock::API.stub_request(:head, /redirect/).to_return(
              :status => 301, :headers => { 'Location' => 'http://banana-corp.local/found/' })
            WebMock::API.stub_request(:head, /found/).to_return(:status => 200)
            Specification.any_instance.stubs(:homepage).returns('http://banana-corp.local/redirect/')
            @validator.validate
            @validator.results.should.be.empty
          end

          it 'does not fail if the homepage does not support HEAD' do
            WebMock::API.stub_request(:head, /page/).to_return(:status => 405)
            WebMock::API.stub_request(:get, /page/).to_return(:status => 200)
            Specification.any_instance.stubs(:homepage).returns('http://banana-corp.local/page/')
            @validator.validate
            @validator.results.should.be.empty
          end

          it 'does not fail if the homepage errors on HEAD' do
            WebMock::API.stub_request(:head, /page/).to_return(:status => 500)
            WebMock::API.stub_request(:get, /page/).to_return(:status => 200)
            Specification.any_instance.stubs(:homepage).returns('http://banana-corp.local/page/')
            @validator.validate
            @validator.results.should.be.empty
          end

          it 'does not follow redirects infinitely' do
            WebMock::API.stub_request(:head, /redirect/).to_return(
              :status => 301,
              :headers => { 'Location' => 'http://banana-corp.local/redirect/' })
            Specification.any_instance.stubs(:homepage).returns(
              'http://banana-corp.local/redirect/')
            @validator.validate
            @validator.results.map(&:to_s).first.should.match /The URL \(.*\) is not reachable/
          end

          it 'supports relative redirects' do
            WebMock::API.stub_request(:head, /redirect/).to_return(
              :status => 302,
              :headers => { 'Location' => '/foo' })
            WebMock::API.stub_request(:head, /foo/).to_return(
              :status => 200)
            Specification.any_instance.stubs(:homepage).returns(
              'http://banana-corp.local/redirect')
            @validator.validate
            @validator.results.should.be.empty
          end
        end

        describe 'Screenshot validation' do
          before do
            @validator.unstub(:validate_screenshots)
            WebMock::API.
              stub_request(:head, 'banana-corp.local/valid-image.png').
              to_return(
                :status => 200,
                :headers => { 'Content-Type' => 'image/png' },
              )
          end

          it 'checks if the screenshots are valid' do
            Specification.any_instance.stubs(:screenshots).
              returns(['http://banana-corp.local/valid-image.png'])
            @validator.validate
            @validator.results.should.be.empty?
          end

          it 'should fail if any of the screenshots URLS do not return an image' do
            WebMock::API.stub_request(:head, 'banana-corp.local/').to_return(:status => 200)
            Specification.any_instance.stubs(:screenshots).returns(['http://banana-corp.local/valid-image.png', 'http://banana-corp.local/'])
            @validator.validate
            @validator.results.map(&:to_s).first.should.match /The screenshot .* is not a valid image/
          end
        end

        describe 'social media URL validation' do
          before do
            @validator.unstub(:validate_social_media_url)
          end

          it 'checks if the social media URL is valid' do
            Specification.any_instance.stubs(:social_media_url).returns('http://banana-corp.local/')
            WebMock::API.stub_request(:head, /banana-corp.local/).to_return(:status => 200)
            @validator.validate
            @validator.results.should.be.empty?
          end

          it "should fail validation if it wasn't able to validate the URL" do
            Specification.any_instance.stubs(:social_media_url).returns('http://banana-corp.local/not-found/')
            WebMock::API.stub_request(:head, /banana-corp.local/).to_return(:status => 404)
            @validator.validate
            @validator.results.map(&:to_s).first.should.match /The URL \(.*\) is not reachable/
          end
        end

        describe 'source URL validation' do
          before do
            @validator.unstub(:validate_source_url)
          end

          it 'checks if the source URL is valid' do
            Specification.any_instance.stubs(:source).returns(:http => 'https://orta.io/package.zip')
            @validator.validate
            @validator.results.should.be.empty?
          end

          it 'should fail validation if the source URL is not HTTPs encrypted' do
            Specification.any_instance.stubs(:source).returns(:http => 'http://orta.io/package.zip')
            @validator.validate
            @validator.results.map(&:to_s).first.should.match /use the encrypted HTTPs protocol./
          end

          it 'should not fail validation if the source URL is using file:///' do
            Specification.any_instance.stubs(:source).returns(:http => 'file:///orta.io/package.zip')
            @validator.validate
            @validator.results.should.be.empty?
          end
        end

        describe 'documentation URL validation' do
          before do
            @validator.unstub(:validate_documentation_url)
          end

          it 'checks if the documentation URL is valid' do
            Specification.any_instance.stubs(:documentation_url).returns('http://banana-corp.local/')
            WebMock::API.stub_request(:head, /banana-corp.local/).to_return(:status => 200)
            @validator.validate
            @validator.results.should.be.empty?
          end

          it "should fail validation if it wasn't able to validate the URL" do
            Specification.any_instance.stubs(:documentation_url).returns('http://banana-corp.local/not-found')
            @validator.validate
            @validator.results.map(&:to_s).first.should.match /The URL (.*) is not reachable/
          end
        end
      end

      it 'respects the no clean option' do
        file = write_podspec(stub_podspec)
        validator = Validator.new(file, config.sources_manager.master.map(&:url))
        validator.stubs(:validate_url)
        validator.no_clean = true
        validator.validate
        validator.validation_dir.should.exist
      end

      describe 'Platforms' do
        it 'builds the pod per platform' do
          file = write_podspec(stub_podspec)
          validator = Validator.new(file, config.sources_manager.master.map(&:url))
          validator.stubs(:validate_url)
          validator.expects(:install_pod).times(4)
          validator.expects(:build_pod).times(4)
          validator.expects(:add_app_project_import).times(4)
          validator.expects(:check_file_patterns).times(4)
          validator.validate
        end

        it 'builds the pod per platform specified' do
          file = write_podspec(stub_podspec)
          validator = Validator.new(file, config.sources_manager.master.map(&:url), %w(ios osx))
          validator.stubs(:validate_url)
          validator.expects(:install_pod).times(2)
          validator.expects(:build_pod).times(2)
          validator.expects(:add_app_project_import).times(2)
          validator.expects(:check_file_patterns).times(2)
          validator.validate
        end

        it 'builds the pod per platform specified, ignoring duplicates' do
          file = write_podspec(stub_podspec)
          validator = Validator.new(file, config.sources_manager.master.map(&:url), %w(ios osx macos ios))
          validator.stubs(:validate_url)
          validator.expects(:install_pod).times(2)
          validator.expects(:build_pod).times(2)
          validator.expects(:add_app_project_import).times(2)
          validator.expects(:check_file_patterns).times(2)
          validator.validate
        end

        it 'only builds the platforms specified' do
          file = write_podspec(stub_podspec)
          validator = Validator.new(file, config.sources_manager.master.map(&:url), %w(ios osx))
          validator.send(:platforms_to_lint, validator.spec).map(&:to_s).sort.should == %w(iOS macOS)

          validator = Validator.new(file, config.sources_manager.master.map(&:url), %w(ios osx watchos tvos))
          validator.send(:platforms_to_lint, validator.spec).map(&:to_s).sort.should == %w(iOS macOS tvOS watchOS)
        end

        it 'raises when given an invalid platform' do
          file = write_podspec(stub_podspec)
          should.raise(Informative) do
            Validator.new(file, config.sources_manager.master.map(&:url), %w(ios amazingos))
          end
        end

        it 'raises when given a platform not supported by the specification' do
          file = write_podspec(stub_podspec)
          validator = Validator.new(file, config.sources_manager.master.map(&:url), %w(ios watchos tvos))
          validator.spec.stubs(:available_platforms).returns([Platform.ios])
          should.raise(Informative) do
            validator.send(:platforms_to_lint, validator.spec)
          end
        end
      end

      it 'builds the pod only once if the first fails with fail_fast' do
        Validator.any_instance.unstub(:xcodebuild)
        validator = Validator.new(podspec_path, config.sources_manager.master.map(&:url))
        validator.stubs(:check_file_patterns)
        validator.stubs(:validate_url)
        validator.fail_fast = true
        validator.expects(:xcodebuild).once.returns('file.m:1:1: error: Pretended!')
        validator.validate
        validator.result_type.should == :error
      end

      it 'uses the deployment target of the specification' do
        validator = Validator.new(podspec_path, config.sources_manager.master.map(&:url))
        validator.stubs(:validate_url)
        validator.stubs(:validate_screenshots)
        podfile = validator.send(:podfile_from_spec, :ios, '5.0')
        dependency = podfile.target_definitions['App'].dependencies.first
        dependency.external_source.key?(:podspec).should.be.true
      end

      it 'uses the deployment target of the current subspec' do
        validator = Validator.new(podspec_path, config.sources_manager.master.map(&:url))
        validator.instance_variable_set(:@results, [])
        validator.stubs(:validate_url)
        validator.stubs(:validate_screenshots)
        validator.stubs(:check_file_patterns)
        validator.stubs(:install_pod)
        validator.stubs(:add_app_project_import)
        %i(prepare resolve_dependencies download_dependencies).each do |m|
          Installer.any_instance.stubs(m)
        end
        Installer.any_instance.stubs(:aggregate_targets).returns([])
        Installer.any_instance.stubs(:pod_targets).returns([])
        subspec = Specification.new(validator.spec, 'subspec') do |s|
          s.ios.deployment_target = '7.0'
        end
        validator.spec.stubs(:subspecs).returns([subspec])
        validator.expects(:podfile_from_spec).with(:osx, nil, nil, [], nil).once.returns(stub('Podfile'))
        validator.expects(:podfile_from_spec).with(:ios, nil, nil, [], nil).once.returns(stub('Podfile'))
        validator.expects(:podfile_from_spec).with(:ios, '7.0', nil, [], nil).once.returns(stub('Podfile'))
        validator.expects(:podfile_from_spec).with(:tvos, nil, nil, [], nil).once.returns(stub('Podfile'))
        validator.expects(:podfile_from_spec).with(:watchos, nil, nil, [], nil).once.returns(stub('Podfile'))
        validator.send(:perform_extensive_analysis, validator.spec)

        validator.results_message.strip.should.be.empty
      end

      describe '#podfile_from_spec' do
        before do
          @validator = Validator.new(podspec_path, config.sources_manager.master.map(&:url))
          @validator.stubs(:validate_url)
        end

        it 'configures the deployment target' do
          podfile = @validator.send(:podfile_from_spec, :ios, '5.0')
          target_definition = podfile.target_definitions['App']
          platform = target_definition.platform
          platform.symbolic_name.should == :ios
          platform.deployment_target.to_s.should == '5.0'
        end

        it 'includes the use_frameworks! directive' do
          podfile = @validator.send(:podfile_from_spec, :ios, '5.0', true)
          target_definition = podfile.target_definitions['App']
          target_definition.uses_frameworks?.should == true
        end

        it 'includes the use_frameworks!(false) directive' do
          podfile = @validator.send(:podfile_from_spec, :ios, '5.0', false)
          target_definition = podfile.target_definitions['App']
          # rubocop:disable Style/DoubleNegation
          (!!target_definition.uses_frameworks?).should == false
          # rubocop:enable Style/DoubleNegation
        end

        it 'includes the use_modular_headers! directive' do
          podfile = @validator.send(:podfile_from_spec, :ios, '5.0', false, [], true)
          target_definition = podfile.target_definitions['App']
          target_definition.use_modular_headers_hash['all'].should.be.true
        end

        it 'inhibits warnings for all pods except the one being validated' do
          podfile = @validator.send(:podfile_from_spec, :ios, '5.0')
          target_definition = podfile.target_definitions['App']
          target_definition.should.not.inhibits_warnings_for_pod?('JSONKit')
          target_definition.should.inhibits_warnings_for_pod?('NotJSONKit')
        end
      end

      it 'empties sources when no dependencies' do
        sources = %w(master https://github.com/CocoaPods/Specs.git)
        Command::Repo::Add.any_instance.stubs(:run)
        validator = Validator.new(podspec_path, sources)
        validator.stubs(:validate_url)
        podfile = validator.send(:podfile_from_spec, :ios, '5.0')
        podfile.sources.should == %w()
      end

      it 'respects the source_urls parameter when there are dependencies' do
        podspec = stub_podspec(/.*name.*/, '"name": "SBJson",').gsub(/.*version.*/, '"version": "3.2",')
        file = write_podspec(podspec, 'SBJson.podspec.json')
        spec = Specification.from_file(file)
        set = mock
        set.stubs(:all_specifications).returns([spec])
        Source::Aggregate.any_instance.stubs(:search).with(Dependency.new('SBJson', '~> 3.2')).returns(set)

        podspec = stub_podspec(/.*name.*/, '"name": "ZKit",')
        podspec.gsub!(/.*requires_arc.*/, '"dependencies": { "SBJson": [ "~> 3.2" ] }, "requires_arc": false')
        file = write_podspec(podspec, 'ZKit.podspec.json')

        spec = Specification.from_file(file)

        sources = %w(master https://github.com/CocoaPods/Specs.git)
        Command::Repo::Add.any_instance.stubs(:run)
        validator = Validator.new(spec, sources)
        validator.stubs(:validate_url)
        podfile = validator.send(:podfile_from_spec, :ios, '5.0')
        podfile.sources.should == %w(https://github.com/CocoaPods/Specs.git)
      end

      it 'respects the source_urls parameter when there are dependencies within subspecs' do
        podspec = stub_podspec(/.*name.*/, '"name": "SBJson",').gsub(/.*version.*/, '"version": "3.2",')
        file = write_podspec(podspec, 'SBJson.podspec.json')
        spec = Specification.from_file(file)
        set = mock
        set.stubs(:all_specifications).returns([spec])
        Source::Aggregate.any_instance.stubs(:search).with(Dependency.new('SBJson', '~> 3.2')).returns(set)

        podspec = stub_podspec(/.*name.*/, '"name": "ZKit",')
        podspec.gsub!(/.*requires_arc.*/, '"subspecs": [ { "name":"SubSpecA", "dependencies": { "SBJson": [ "~> 3.2" ] } } ], "requires_arc": false')
        file = write_podspec(podspec, 'ZKit.podspec.json')

        spec = Specification.from_file(file)

        sources = %w(master https://github.com/CocoaPods/Specs.git)
        Command::Repo::Add.any_instance.stubs(:run)
        validator = Validator.new(spec, sources)
        validator.stubs(:validate_url)
        podfile = validator.send(:podfile_from_spec, :ios, '5.0')
        podfile.sources.should == %w(https://github.com/CocoaPods/Specs.git)
      end

      it 'avoids creation of sources when no dependencies' do
        sources = %w(master https://github.com/CocoaPods/Specs.git)
        config.sources_manager.expects(:find_or_create_source_with_url).never
        Command::Repo::Add.any_instance.stubs(:run)
        validator = Validator.new(podspec_path, sources)
        validator.stubs(:validate_url)
        validator.validate
      end

      it 'uses xcodebuild to generate warnings' do
        validator = Validator.new(podspec_path, config.sources_manager.master.map(&:url))
        validator.stubs(:check_file_patterns)
        validator.stubs(:xcodebuild).returns("file.m:1:1: warning: 'dataFromPropertyList:format:errorDescription:' is deprecated: first deprecated in iOS 8.0 - Use dataWithPropertyList:format:options:error: instead. [-Wdeprecated-declarations]")
        validator.stubs(:validate_url)
        validator.validate
        first = validator.results.map(&:to_s).first
        first.should.include '[xcodebuild]'
        validator.result_type.should == :warning
      end

      it 'uses xcodebuild to generate notes' do
        validator = Validator.new(podspec_path, config.sources_manager.master.map(&:url))
        validator.stubs(:check_file_patterns)
        validator.stubs(:xcodebuild).returns("file.m:1:1: note: 'dataFromPropertyList:format:errorDescription:' has been explicitly marked deprecated here")
        validator.stubs(:validate_url)
        validator.validate
        first = validator.results.map(&:to_s).first
        first.should.include '[xcodebuild]'
        validator.result_type.should == :note
      end

      it 'checks if xcodebuild returns a successful status code' do
        require 'fourflusher'
        Fourflusher::SimControl.any_instance.stubs(:destination).returns(['-destination', 'id=XXX'])
        Validator.any_instance.unstub(:xcodebuild)
        validator = Validator.new(podspec_path, config.sources_manager.master.map(&:url))
        validator.stubs(:check_file_patterns)
        validator.stubs(:validate_url)
        git = Executable.which(:git)
        Executable.stubs(:which).with('git').returns(git)
        Executable.stubs(:which).with(:xcrun)
        validator.stubs(:_xcodebuild).raises(Informative)
        validator.validate
        first = validator.results.map(&:to_s).first
        first.should.include '[xcodebuild] Returned an unsuccessful exit code'
        validator.result_type.should == :error
      end

      it 'runs xcodebuild with correct arguments when skipping import validation' do
        require 'fourflusher'
        Fourflusher::SimControl.any_instance.stubs(:destination).returns(['-destination', 'id=XXX'])
        Validator.any_instance.unstub(:xcodebuild)
        PodTarget.any_instance.stubs(:should_build?).returns(true)
        validator = Validator.new(podspec_path, config.sources_manager.master.map(&:url))
        validator.stubs(:check_file_patterns)
        validator.stubs(:validate_url)
        validator.skip_import_validation = true
        git = Executable.which(:git)
        Executable.stubs(:which).with('git').returns(git)
        Executable.stubs(:capture_command).with('git', ['config', '--get', 'remote.origin.url'], :capture => :out).returns(['https://github.com/CocoaPods/Specs.git'])
        Executable.stubs(:which).with(:xcrun)
        Executable.expects(:execute_command).with { |executable, command, _| executable == 'git' && command.first == 'clone' }.once
        # Command should include the pod target 'JSONKit' instead of the 'App' target.
        command = ['clean', 'build', '-workspace', File.join(validator.validation_dir, 'App.xcworkspace'), '-scheme', 'JSONKit', '-configuration', 'Release']
        args = %w(CODE_SIGN_IDENTITY=)
        Executable.expects(:execute_command).with('xcodebuild', command + args, true).once.returns('')
        args = %w(CODE_SIGN_IDENTITY=- -sdk appletvsimulator) + Fourflusher::SimControl.new.destination('Apple TV 1080p')
        Executable.expects(:execute_command).with('xcodebuild', command + args, true).once.returns('')
        args = %w(CODE_SIGN_IDENTITY=- -sdk iphonesimulator) + Fourflusher::SimControl.new.destination('iPhone 4s')
        Executable.expects(:execute_command).with('xcodebuild', command + args, true).once.returns('')
        args = %w(CODE_SIGN_IDENTITY=- -sdk watchsimulator) + Fourflusher::SimControl.new.destination('Apple Watch - 38mm')
        Executable.expects(:execute_command).with('xcodebuild', command + args, true).once.returns('')
        validator.validate
      end

      it 'runs xcodebuild with correct arguments for code signing' do
        require 'fourflusher'
        Fourflusher::SimControl.any_instance.stubs(:destination).returns(['-destination', 'id=XXX'])
        Validator.any_instance.unstub(:xcodebuild)
        validator = Validator.new(podspec_path, config.sources_manager.master.map(&:url))
        validator.stubs(:check_file_patterns)
        validator.stubs(:validate_url)
        git = Executable.which(:git)
        Executable.stubs(:which).with('git').returns(git)
        Executable.stubs(:capture_command).with('git', ['config', '--get', 'remote.origin.url'], :capture => :out).returns(['https://github.com/CocoaPods/Specs.git'])
        Executable.stubs(:which).with(:xcrun)
        Executable.expects(:execute_command).with { |executable, command, _| executable == 'git' && command.first == 'clone' }.once
        command = ['clean', 'build', '-workspace', File.join(validator.validation_dir, 'App.xcworkspace'), '-scheme', 'App', '-configuration', 'Release']
        args = %w(CODE_SIGN_IDENTITY=)
        Executable.expects(:execute_command).with('xcodebuild', command + args, true).once.returns('')
        args = %w(CODE_SIGN_IDENTITY=- -sdk appletvsimulator) + Fourflusher::SimControl.new.destination('Apple TV 1080p')
        Executable.expects(:execute_command).with('xcodebuild', command + args, true).once.returns('')
        args = %w(CODE_SIGN_IDENTITY=- -sdk iphonesimulator) + Fourflusher::SimControl.new.destination('iPhone 4s')
        Executable.expects(:execute_command).with('xcodebuild', command + args, true).once.returns('')
        args = %w(CODE_SIGN_IDENTITY=- -sdk watchsimulator) + Fourflusher::SimControl.new.destination('Apple Watch - 38mm')
        Executable.expects(:execute_command).with('xcodebuild', command + args, true).once.returns('')
        validator.validate
      end

      it 'sets the -Wincomplete-umbrella compiler flag for pod targets' do
        validator = Validator.new(podspec_path, config.sources_manager.master.map(&:url))
        validator.no_clean = true
        validator.stubs(:check_file_patterns)
        validator.stubs(:validate_url)
        validator.validate

        pods_project = Xcodeproj::Project.open(validator.validation_dir + 'Pods/Pods.xcodeproj')

        pods_project.native_targets.find { |nt| nt.name == 'JSONKit' }.resolved_build_setting('OTHER_CFLAGS').each do |_, value|
          value.should == %w($(inherited) -Wincomplete-umbrella)
        end
      end

      it 'does filter InputFile errors completely' do
        validator = Validator.new(podspec_path, config.sources_manager.master.map(&:url))
        validator.stubs(:check_file_patterns)
        validator.stubs(:xcodebuild).returns("2014-10-01 06:27:36.693 xcodebuild[61207:2007] error: InputFile    Target Support Files/Pods-OneUpFoundation/Pods-OneUpFoundation-prefix.pch 0 1412159238 77 33188... malformed line 10; 'InputFile' should have exactly five arguments")
        validator.stubs(:validate_url)
        validator.validate
        validator.results.count.should == 0
      end

      it 'does filter embedded frameworks warnings' do
        validator = Validator.new(podspec_path, config.sources_manager.master.map(&:url))
        validator.stubs(:check_file_patterns)
        validator.stubs(:xcodebuild).returns('ld: warning: embedded dylibs/frameworks only run on iOS 8 or later.')
        validator.stubs(:validate_url)
        validator.validate
        validator.results.count.should == 0
      end

      describe 'import validation' do
        before do
          @validator = Validator.new(podspec_path, config.sources_manager.master.map(&:url))
          @validator.stubs(:validate_url)
          @consumer = Specification.from_file(podspec_path).consumer(:ios)
          @validator.instance_variable_set(:@consumer, @consumer)
          @validator.send(:setup_validation_environment)
        end

        after do
          @validator.send(:tear_down_validation_environment)
        end

        it 'creates an empty app project & target to integrate into' do
          @validator.send(:create_app_project)
          project = Xcodeproj::Project.open(@validator.validation_dir + 'App.xcodeproj')

          target = project.native_targets.find { |t| t.name == 'App' }
          target.should.not.be.nil
          target.symbol_type.should == :application
          target.deployment_target.should.be.nil
          target.platform_name.should == :ios

          Xcodeproj::Project.schemes(project.path).should == %w(App)
        end

        it 'adds the importing file to the app target' do
          @validator.stubs(:use_frameworks).returns(true)
          @validator.send(:create_app_project)
          pods_project = Xcodeproj::Project.new(@validator.validation_dir + 'Pods/Pods.xcodeproj')
          app_project_path = @validator.validation_dir + 'App.xcodeproj'
          pod_target = fixture_pod_target('banana-lib/BananaLib.podspec')
          pod_target.stubs(:uses_swift? => true, :pod_name => 'JSONKit')
          installer = stub(:pod_targets => [pod_target])
          installer.stubs(:pods_project).returns(pods_project)
          Xcodeproj::XCScheme.expects(:share_scheme).with(app_project_path, 'App').once
          Xcodeproj::XCScheme.expects(:share_scheme).with(pods_project.path, 'BananaLib').once
          @validator.stubs(:shares_pod_target_xcscheme?).returns(true)
          @validator.instance_variable_set(:@installer, installer)
          @validator.send(:add_app_project_import)

          project = Xcodeproj::Project.open(@validator.validation_dir + 'App.xcodeproj')
          group = project['App']
          file = group.find_file_by_path('main.swift')
          file.should.not.be.nil
          target = project.native_targets.find { |t| t.name == 'App' }
          target.source_build_phase.files_references.should.include(file)
        end

        it 'adds developer framework paths when the pod depends on XCTest' do
          @validator.send(:create_app_project)
          pods_project = Xcodeproj::Project.new(@validator.validation_dir + 'Pods/Pods.xcodeproj')
          app_project_path = @validator.validation_dir + 'App.xcodeproj'
          pod_target = fixture_pod_target('banana-lib/BananaLib.podspec')
          pod_target.stubs(:uses_swift? => true, :pod_name => 'JSONKit')
          pod_target.spec_consumers.first.stubs(:frameworks).returns(%w(XCTest))
          installer = stub(:pod_targets => [pod_target])
          installer.stubs(:pods_project).returns(pods_project)
          Xcodeproj::XCScheme.expects(:share_scheme).with(app_project_path, 'App').once
          Xcodeproj::XCScheme.expects(:share_scheme).with(pods_project.path, 'BananaLib').once
          @validator.stubs(:shares_pod_target_xcscheme?).returns(true)
          @validator.instance_variable_set(:@installer, installer)
          @validator.send(:add_app_project_import)

          app_project = Xcodeproj::Project.open(app_project_path)
          app_project.native_targets.first.build_configurations.map do |bc|
            bc.build_settings['FRAMEWORK_SEARCH_PATHS']
          end.uniq.should == [%w($(inherited) "$(PLATFORM_DIR)/Developer/Library/Frameworks")]
        end

        it 'does not share xcscheme for pod target if there isnt one' do
          @validator.send(:create_app_project)
          pods_project = Xcodeproj::Project.new(@validator.validation_dir + 'Pods/Pods.xcodeproj')
          app_project_path = @validator.validation_dir + 'App.xcodeproj'
          pod_target = fixture_pod_target('banana-lib/BananaLib.podspec')
          pod_target.stubs(:uses_swift? => true, :pod_name => 'JSONKit')
          pod_target.spec_consumers.first.stubs(:frameworks).returns(%w(XCTest))
          installer = stub(:pod_targets => [pod_target])
          installer.stubs(:pods_project).returns(pods_project)
          Xcodeproj::XCScheme.expects(:share_scheme).with(app_project_path, 'App').once
          Xcodeproj::XCScheme.expects(:share_scheme).with(pods_project.path, 'BananaLib').never
          @validator.stubs(:shares_pod_target_xcscheme?).returns(false)
          @validator.instance_variable_set(:@installer, installer)
          @validator.send(:add_app_project_import)
        end
      end

      describe 'file pattern validation' do
        it 'checks for file patterns' do
          file = write_podspec(stub_podspec(/.*source_files.*/, '"source_files": "wrong_paht.*",'))
          validator = Validator.new(file, config.sources_manager.master.map(&:url))
          validator.stubs(:build_pod)
          validator.stubs(:validate_url)
          validator.validate
          validator.results.map(&:to_s).first.should.match /source_files.*did not match/
          validator.result_type.should == :error
        end

        it 'checks private_header_files matches only headers' do
          file = write_podspec(stub_podspec(/.*source_files.*/, '"source_files": "JSONKit.*", "private_header_files": "JSONKit.m",'))
          validator = Validator.new(file, config.sources_manager.master.map(&:url))
          validator.stubs(:build_pod)
          validator.stubs(:validate_url)
          validator.validate
          validator.results.map(&:to_s).first.should.match /matches non-header files \(JSONKit\.m\)/
          validator.result_type.should == :error
        end

        it 'checks public_header_files matches only headers' do
          file = write_podspec(stub_podspec(/.*source_files.*/, '"source_files": "JSONKit.*", "public_header_files": "JSONKit.m",'))
          validator = Validator.new(file, config.sources_manager.master.map(&:url))
          validator.stubs(:build_pod)
          validator.stubs(:validate_url)
          validator.validate
          validator.results.map(&:to_s).first.should.match /matches non-header files \(JSONKit\.m\)/
          validator.result_type.should == :error
        end

        it 'warns if public_header_files does not match any files' do
          file = write_podspec(stub_podspec(/.*source_files.*/, '"source_files": "JSONKit.*", "public_header_files": "MissingHeader.h",'))
          validator = Validator.new(file, config.sources_manager.master.map(&:url))
          validator.stubs(:build_pod)
          validator.stubs(:validate_url)
          validator.validate
          validator.results.map(&:to_s).first.should.match /The `public_header_files` pattern did not match any file./
          validator.result_type.should == :warning
        end

        it 'warns if private_header_files does not match any files' do
          file = write_podspec(stub_podspec(/.*source_files.*/, '"source_files": "JSONKit.*", "private_header_files": "MissingHeader.h",'))
          validator = Validator.new(file, config.sources_manager.master.map(&:url))
          validator.stubs(:build_pod)
          validator.stubs(:validate_url)
          validator.validate
          validator.results.map(&:to_s).first.should.match /The `private_header_files` pattern did not match any file./
          validator.result_type.should == :warning
        end

        it 'checks presence of license file' do
          file = write_podspec(stub_podspec(/.*license.*$/, '"license": "MIT",'))
          validator = Validator.new(file, config.sources_manager.master.map(&:url))
          validator.stubs(:build_pod)
          validator.stubs(:validate_url)
          validator.validate
          validator.results.map(&:to_s).first.should.match /Unable to find a license file/
          validator.result_type.should == :warning
        end

        it 'checks module_map must exist if specified' do
          file = write_podspec(stub_podspec(/.*source_files.*/, '"source_files": "JSONKit.*", "module_map": "JSONKit.modulemap",'))
          validator = Validator.new(file, config.sources_manager.master.map(&:url))
          validator.stubs(:build_pod)
          validator.stubs(:validate_url)
          validator.validate
          validator.results.map(&:to_s).first.should.match /Unable to find the specified module map file./
          validator.result_type.should == :error
        end

        it 'checks module_map accepts only modulemaps' do
          file = write_podspec(stub_podspec(/.*source_files.*/, '"source_files": "JSONKit.*", "module_map": "JSONKit.m",'))
          validator = Validator.new(file, config.sources_manager.master.map(&:url))
          validator.stubs(:build_pod)
          validator.stubs(:validate_url)
          validator.validate
          validator.results.map(&:to_s).first.should.match /Unexpected file extension for modulemap file \(JSONKit\.m\)/
          validator.result_type.should == :error
        end

        it 'checks resource bundles have resources' do
          file = write_podspec(stub_podspec(/.*source_files.*/, <<-JSON))
            "source_files": "JSONKit.*",
            "resource_bundles": {
              "bundle1": ["CHANGELOG.md", "*.md"],
              "bundle2": "foo.bar*"
            },
          JSON

          validator = Validator.new(file, config.sources_manager.master.map(&:url))
          validator.stubs(:build_pod)
          validator.stubs(:validate_url)
          validator.validate
          validator.results.map(&:to_s).first.should.include 'The `resource_bundles` pattern for `bundle2` did not match any file'
          validator.result_type.should == :error
        end
      end

      it 'validates a podspec with dependencies' do
        podspec = stub_podspec(/.*name.*/, '"name": "SBJson",').gsub(/.*version.*/, '"version": "3.2",')
        file = write_podspec(podspec, 'SBJson.podspec.json')
        spec = Specification.from_file(file)
        set = mock
        set.stubs(:all_specifications).returns([spec])
        Source::Aggregate.any_instance.stubs(:search).with(Dependency.new('SBJson', '~> 3.2')).returns(set)

        podspec = stub_podspec(/.*name.*/, '"name": "ZKit",')
        podspec.gsub!(/.*requires_arc.*/, '"dependencies": { "SBJson": [ "~> 3.2" ] }, "requires_arc": false')
        file = write_podspec(podspec, 'ZKit.podspec.json')

        spec = Specification.from_file(file)
        validator = Validator.new(spec, config.sources_manager.master.map(&:url))
        validator.stubs(:validate_url)
        validator.stubs(:build_pod)
        validator.validate
        validator.validated?.should.be.true
      end
    end

    describe 'frameworks' do
      before do
        @validator = Validator.new(podspec_path, config.sources_manager.master.map(&:url))
      end

      def setup_validator
        @validator.instance_variable_set(:@results, [])
        @validator.stubs(:validate_url)
        @validator.stubs(:validate_screenshots)
        @validator.stubs(:check_file_patterns)
        @validator.stubs(:install_pod)
        @validator.stubs(:add_app_project_import)
        %i(prepare resolve_dependencies download_dependencies).each do |m|
          Installer.any_instance.stubs(m)
        end
        Installer.any_instance.stubs(:aggregate_targets).returns([])
        Installer.any_instance.stubs(:pod_targets).returns([])
      end

      it 'lints as a framework if specified' do
        @validator.use_frameworks = true

        setup_validator

        @validator.expects(:podfile_from_spec).with(:osx, nil, true, [], nil).once.returns(stub('Podfile'))
        @validator.expects(:podfile_from_spec).with(:ios, '8.0', true, [], nil).once.returns(stub('Podfile'))
        @validator.expects(:podfile_from_spec).with(:tvos, nil, true, [], nil).once.returns(stub('Podfile'))
        @validator.expects(:podfile_from_spec).with(:watchos, nil, true, [], nil).once.returns(stub('Podfile'))
        @validator.send(:perform_extensive_analysis, @validator.spec)

        @validator.results_message.strip.should.be.empty
      end

      it 'lint as a static library if specified' do
        @validator.use_frameworks = false

        setup_validator

        @validator.expects(:podfile_from_spec).with(:osx, nil, false, [], nil).once.returns(stub('Podfile'))
        @validator.expects(:podfile_from_spec).with(:ios, nil, false, [], nil).once.returns(stub('Podfile'))
        @validator.expects(:podfile_from_spec).with(:tvos, nil, false, [], nil).once.returns(stub('Podfile'))
        @validator.expects(:podfile_from_spec).with(:watchos, nil, false, [], nil).once.returns(stub('Podfile'))
        @validator.send(:perform_extensive_analysis, @validator.spec)

        @validator.results_message.strip.should.be.empty
      end

      it 'shows an error when performing extensive analysis on a test spec' do
        setup_validator
        subspec = Specification.new(@validator.spec, 'Tests', true)
        @validator.send(:perform_extensive_analysis, subspec)
        @validator.results.map(&:to_s).first.should.include 'Validating a test spec (`JSONKit/Tests`) is not supported.'
        @validator.result_type.should == :error
      end
    end

    describe 'dynamic binaries validation' do
      it 'fails with dynamic binaries on iOS < 8' do
        podspec = stub_podspec(/.*license.*$/, '"license": "Public Domain",')
        file = write_podspec(podspec)

        Pod::Sandbox::FileAccessor.any_instance.stubs(:vendored_libraries).returns([fixture('empty.dylib')])
        validator = Validator.new(file, config.sources_manager.master.map(&:url))
        validator.stubs(:build_pod)
        validator.stubs(:validate_url)
        validator.validate

        validator.results.map(&:to_s).first.should.match /Dynamic frameworks.*iOS 8.0 and onwards/
        validator.result_type.should == :error
      end
    end

    describe 'swift validation' do
      def test_swiftpod
        podspec = stub_podspec(/.*source_files.*/, '"source_files": "*.swift",')
        file = write_podspec(podspec)
        pathname = Pathname.new('/Foo.swift')
        pathname.stubs(:realpath).returns(pathname)

        Podfile::TargetDefinition.any_instance.stubs(:uses_frameworks?).returns(true)
        Pod::Sandbox::FileAccessor.any_instance.stubs(:source_files).returns([pathname])
        Pod::Installer::PodSourceInstaller.any_instance.stubs(:lock_files!)
        Pod::Installer::PodSourceInstaller.any_instance.stubs(:unlock_files!)
        validator = Validator.new(file, config.sources_manager.master.map(&:url))
        validator.stubs(:build_pod)
        validator.stubs(:validate_url)
        validator
      end

      def test_swiftpod_with_dot_swift_version(version = '3.1.0')
        validator = test_swiftpod
        validator.stubs(:dot_swift_version).returns(version)
        validator
      end

      it 'fails on deployment target < iOS 8 for Swift Pods' do
        validator = test_swiftpod_with_dot_swift_version
        validator.validate

        validator.results.map(&:to_s).first.should.match /dynamic frameworks.*iOS > 8/
        validator.result_type.should == :error
      end

      it 'succeeds on deployment target < iOS 8 for Swift Pods using XCTest' do
        Specification::Consumer.any_instance.stubs(:frameworks).returns(%w(XCTest))

        validator = test_swiftpod_with_dot_swift_version
        validator.validate
        validator.results.count.should == 0
      end

      it 'succeeds on deployment targets >= iOS 8 for Swift Pods' do
        Specification.any_instance.stubs(:deployment_target).returns('9.0')

        validator = test_swiftpod_with_dot_swift_version
        validator.validate

        validator.results.count.should == 0
      end

      describe 'with a user provided swift-version' do
        it 'succeeds with a --swift-version provided value' do
          Specification.any_instance.stubs(:deployment_target).returns('9.0')

          validator = test_swiftpod
          validator.swift_version = '3.1.0'
          validator.validate
          validator.results.count.should == 0
        end

        it 'succeeds with a .swift-version file' do
          Specification.any_instance.stubs(:deployment_target).returns('9.0')

          validator = test_swiftpod_with_dot_swift_version
          validator.validate
          validator.results.count.should == 0
        end
      end

      describe 'without a user provided swift version' do
        it 'warns for Swift Pods' do
          Specification.any_instance.stubs(:deployment_target).returns('9.0')

          validator = test_swiftpod
          validator.validate
          validator.results.count.should == 1

          result = validator.results.first
          result.type.should == :warning
          result.message.should == 'The validator used ' \
            'Swift 3.2 by default because no Swift version was specified. ' \
            'To specify a Swift version during validation, add the `swift_version` attribute in your podspec. ' \
            'Note that usage of the `--swift-version` parameter or a `.swift-version` file is now deprecated.'
        end

        it 'errors when swift version spec attribute does not match dot swift version' do
          Specification.any_instance.stubs(:deployment_target).returns('9.0')
          Specification.any_instance.stubs(:swift_version).returns(Version.new('4.0'))

          validator = test_swiftpod_with_dot_swift_version('3.2')
          validator.validate
          validator.results.count.should == 1

          result = validator.results.first
          result.type.should == :error
          result.message.should == 'Specification `JSONKit` specifies an inconsistent `swift_version` (`4.0`) compared to the one present in your `.swift-version` file (`3.2`). ' \
                                   'Please remove the `.swift-version` file which is now deprecated and only use the `swift_version` attribute within your podspec.'
        end

        it 'does not error when swift version spec attribute matches dot swift version' do
          Specification.any_instance.stubs(:deployment_target).returns('9.0')
          Specification.any_instance.stubs(:swift_version).returns(Version.new('4.0'))

          validator = test_swiftpod_with_dot_swift_version('4.0')
          validator.validate
          validator.results.count.should == 0
        end

        it 'errors when swift version spec attribute does not match parameter based swift version' do
          Specification.any_instance.stubs(:deployment_target).returns('9.0')
          Specification.any_instance.stubs(:swift_version).returns(Version.new('4.0'))

          validator = test_swiftpod
          validator.swift_version = '3.2'
          validator.validate
          validator.results.count.should == 1

          result = validator.results.first
          result.type.should == :error
          result.message.should == 'Specification `JSONKit` specifies an inconsistent `swift_version` (`4.0`) compared to the one passed during lint (`3.2`).'
        end

        it 'does not error when swift version spec attribute matches parameter based swift version' do
          Specification.any_instance.stubs(:deployment_target).returns('9.0')
          Specification.any_instance.stubs(:swift_version).returns(Version.new('4.0'))

          validator = test_swiftpod
          validator.swift_version = '4.0'
          validator.validate
          validator.results.count.should == 0
        end

        it 'does not warn for Swift if version was set by a dot swift version file' do
          Specification.any_instance.stubs(:deployment_target).returns('9.0')

          validator = test_swiftpod_with_dot_swift_version
          validator.validate
          validator.results.count.should == 0
        end

        it 'does not warn for Swift if version was set as a parameter' do
          Specification.any_instance.stubs(:deployment_target).returns('9.0')

          validator = test_swiftpod
          validator.stubs(:dot_swift_version).returns(nil)
          validator.swift_version = '3.1.0'
          validator.validate
          validator.results.count.should == 0
        end
      end

      describe '#swift_version' do
        it 'defaults to Swift 3.2' do
          validator = test_swiftpod
          validator.stubs(:dot_swift_version).returns(nil)
          validator.swift_version.should == '3.2'
        end

        it 'uses the Swift version specified by the swift_version attribute in the spec' do
          validator = test_swiftpod
          validator.spec.swift_version = '4.0'
          validator.swift_version.should == '4.0'
        end

        it 'allows the user to set the Swift version using a .swift-version file' do
          validator = test_swiftpod
          validator.stubs(:dot_swift_version).returns('3.0')
          validator.swift_version = '4.0'
          validator.swift_version.should == '4.0'
        end

        it 'checks for dot_swift_version' do
          validator = test_swiftpod
          validator.expects(:dot_swift_version)
          validator.swift_version
        end

        it 'uses the result of dot_swift_version if not nil' do
          validator = test_swiftpod
          validator.stubs(:dot_swift_version).returns('1.0')
          validator.swift_version.should == '1.0'
        end
      end

      describe '#dot_swift_version' do
        it 'looks for a .swift-version file' do
          validator = test_swiftpod
          Pathname.any_instance.expects(:exist?)
          validator.dot_swift_version
        end

        it 'uses the .swift-version file if present' do
          validator = test_swiftpod
          Pathname.any_instance.stubs(:exist?).returns(true)
          Pathname.any_instance.expects(:read).returns('1.0')
          validator.dot_swift_version.should == '1.0'
        end

        it 'strips newlines from .swift-version files' do
          validator = test_swiftpod
          Pathname.any_instance.stubs(:exist?).returns(true)
          Pathname.any_instance.stubs(:read).returns("2.1\n")
          validator.swift_version.should == '2.1'
        end
      end

      describe 'Getting the Swift value used by the validator' do
        it 'passes nil when no targets have used Swift' do
          validator = test_swiftpod
          pod_target = stub(:uses_swift? => true)
          installer = stub(:pod_targets => [pod_target])
          validator.instance_variable_set(:@installer, installer)

          validator.stubs(:dot_swift_version).returns('1.2.3')
          validator.uses_swift?.should.be.true
        end

        it 'returns the swift_version when a target has used Swift' do
          validator = test_swiftpod
          pod_target = stub(:uses_swift? => false)
          installer = stub(:pod_targets => [pod_target])
          validator.instance_variable_set(:@installer, installer)

          validator.uses_swift?.should.be.false
        end

        it 'honors swift version set by the pod target for dependencies' do
          validator = test_swiftpod
          consumer = stub(:platform_name => 'iOS')
          validator.instance_variable_set(:@consumer, consumer)
          debug_configuration_one = stub(:build_settings => {})
          debug_configuration_two = stub(:build_settings => {})
          native_target_one = stub(:build_configuration_list => stub(:build_configurations => [debug_configuration_one]))
          native_target_two = stub(:build_configuration_list => stub(:build_configurations => [debug_configuration_two]))
          pod_target_one = stub(:name => 'PodTarget1', :uses_swift? => true, :swift_version => '4.0')
          pod_target_two = stub(:name => 'PodTarget2', :uses_swift? => true, :swift_version => '3.2')
          pod_target_installation_one = stub(:target => pod_target_one, :native_target => native_target_one,
                                             :test_native_targets => [],
                                             :test_specs_by_native_target => {})
          pod_target_installation_two = stub(:target => pod_target_two, :native_target => native_target_two,
                                             :test_native_targets => [],
                                             :test_specs_by_native_target => {})
          pod_target_installation_results = { 'PodTarget1' => pod_target_installation_one, 'PodTarget2' => pod_target_installation_two }
          aggregate_target = stub(:pod_targets => [pod_target_one, pod_target_two])
          installer = stub(:pod_targets => [pod_target_one, pod_target_two])
          validator.instance_variable_set(:@installer, installer)
          validator.send(:configure_pod_targets, [aggregate_target], [pod_target_installation_results], '9.0')
          debug_configuration_one.build_settings['SWIFT_VERSION'].should == '4.0'
          debug_configuration_two.build_settings['SWIFT_VERSION'].should == '3.2'
        end

        it 'honors swift version set by the pod target for dependencies that are not part of the aggregate target' do
          validator = test_swiftpod
          consumer = stub(:platform_name => 'iOS')
          validator.instance_variable_set(:@consumer, consumer)
          debug_configuration_one = stub(:build_settings => {})
          debug_configuration_two = stub(:build_settings => {})
          native_target_one = stub(:build_configuration_list => stub(:build_configurations => [debug_configuration_one]))
          native_target_two = stub(:build_configuration_list => stub(:build_configurations => [debug_configuration_two]))
          pod_target_one = stub(:name => 'PodTarget1', :uses_swift? => true, :swift_version => '4.0')
          pod_target_two = stub(:name => 'PodTarget2', :uses_swift? => true, :swift_version => '3.2')
          pod_target_installation_one = stub(:target => pod_target_one, :native_target => native_target_one,
                                             :test_native_targets => [],
                                             :test_specs_by_native_target => {})
          pod_target_installation_two = stub(:target => pod_target_two, :native_target => native_target_two,
                                             :test_native_targets => [],
                                             :test_specs_by_native_target => {})
          pod_target_installation_results = { 'PodTarget1' => pod_target_installation_one, 'PodTarget2' => pod_target_installation_two }
          aggregate_target = stub(:pod_targets => [pod_target_one])
          installer = stub(:pod_targets => [pod_target_one, pod_target_two])
          validator.instance_variable_set(:@installer, installer)
          validator.send(:configure_pod_targets, [aggregate_target], [pod_target_installation_results], '9.0')
          debug_configuration_one.build_settings['SWIFT_VERSION'].should == '4.0'
          debug_configuration_two.build_settings['SWIFT_VERSION'].should == '3.2'
        end
      end
    end

    #-------------------------------------------------------------------------#
  end
end
