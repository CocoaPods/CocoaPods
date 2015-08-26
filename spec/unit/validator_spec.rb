require File.expand_path('../../spec_helper', __FILE__)
require 'webmock'

module Bacon
  class Context
    alias_method :after_webmock, :after
    def after(&block)
      after_webmock do
        block.call
        WebMock.reset!
      end
    end
  end
end

module Pod
  describe Validator do
    before do
      Validator.any_instance.stubs(:xcodebuild).returns('')
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
      spec = (fixture('spec-repos') + 'master/Specs/JSONKit/1.4/JSONKit.podspec.json').read
      spec.gsub!(/.*license.*$/, '"license": "Public Domain",')
      spec.gsub!(%r{https://github\.com/johnezang/JSONKit\.git}, fixture('integration/JSONKit').to_s)
      spec.gsub!(pattern, replacement) if pattern && replacement
      spec
    end

    # @return [Pathname]
    #
    def podspec_path
      fixture('spec-repos') + 'master/Specs/JSONKit/1.4/JSONKit.podspec.json'
    end

    #-------------------------------------------------------------------------#

    describe 'Quick mode' do
      it 'validates a correct podspec' do
        validator = Validator.new(podspec_path, SourcesManager.master.map(&:url))
        validator.quick = true
        validator.validate
        validator.results.should == []
        validator.validated?.should.be.true
      end

      it 'lints the podspec during validation' do
        podspec = stub_podspec(/.*name.*/, '"name": "TEST",')
        file = write_podspec(podspec)
        validator = Validator.new(file, SourcesManager.master.map(&:url))
        validator.quick = true
        validator.validate
        validator.results.map(&:to_s).first.should.match /should match the name/
        validator.validated?.should.be.false
      end

      it 'respects quick mode' do
        file = write_podspec(stub_podspec)
        validator = Validator.new(file, SourcesManager.master.map(&:url))
        validator.quick = true
        validator.expects(:perform_extensive_analysis).never
        validator.validate
      end

      it 'respects the allow warnings option' do
        podspec = stub_podspec(/.*summary.*/, '"summary": "A short description of",')
        file = write_podspec(podspec)
        validator = Validator.new(file, SourcesManager.master.map(&:url))
        validator.quick = true
        validator.allow_warnings = true
        validator.validate
        validator.results.map(&:to_s).first.should.match /summary.*meaningful/
        validator.validated?.should.be.true
      end

      it 'handles symlinks' do
        file = write_podspec(stub_podspec)
        validator = Validator.new(file, SourcesManager.master.map(&:url))
        validator.quick = true
        validator.stubs(:validate_url)
        validator.validate
        validator.validation_dir.should.be == Pathname.new(Dir.tmpdir) + 'CocoaPods/Lint'
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Extensive analysis' do
      describe 'URL validation' do
        before do
          @validator = Validator.new(podspec_path, SourcesManager.master.map(&:url))
          @validator.stubs(:download_pod)
          @validator.stubs(:check_file_patterns)
          @validator.stubs(:install_pod)
          @validator.stubs(:build_pod)
          @validator.stubs(:tear_down_validation_environment)
          WebMock::API.stub_request(:head, /not-found/).to_return(:status => 404)
          WebMock::API.stub_request(:get, /not-found/).to_return(:status => 404)
        end

        describe 'Homepage validation' do
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
            @validator.results.length.should.equal 0
          end

          it 'does not fail if the homepage does not support HEAD' do
            WebMock::API.stub_request(:head, /page/).to_return(:status => 405)
            WebMock::API.stub_request(:get, /page/).to_return(:status => 200)
            Specification.any_instance.stubs(:homepage).returns('http://banana-corp.local/page/')
            @validator.validate
            @validator.results.length.should.equal 0
          end

          it 'does not fail if the homepage errors on HEAD' do
            WebMock::API.stub_request(:head, /page/).to_return(:status => 500)
            WebMock::API.stub_request(:get, /page/).to_return(:status => 200)
            Specification.any_instance.stubs(:homepage).returns('http://banana-corp.local/page/')
            @validator.validate
            @validator.results.length.should.equal 0
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
            @validator.results.length.should.equal 0
          end
        end

        describe 'Screenshot validation' do
          before do
            @validator.stubs(:validate_homepage)
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
            @validator.stubs(:validate_homepage)
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

        describe 'documentation URL validation' do
          before do
            @validator.stubs(:validate_homepage)
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

        describe 'docset URL validation' do
          before do
            @validator.stubs(:validate_homepage)
          end

          it 'checks if the docset URL is valid' do
            Specification.any_instance.stubs(:docset_url).returns('http://banana-corp.local/')
            WebMock::API.stub_request(:head, /banana-corp.local/).to_return(:status => 200)
            @validator.validate
            @validator.results.should.be.empty?
          end

          it "should fail validation if it wasn't able to validate the URL" do
            Specification.any_instance.stubs(:docset_url).returns('http://banana-corp.local/not-found')
            @validator.validate
            @validator.results.map(&:to_s).first.should.match /The URL (.*) is not reachable/
          end
        end
      end

      it 'respects the no clean option' do
        file = write_podspec(stub_podspec)
        validator = Validator.new(file, SourcesManager.master.map(&:url))
        validator.stubs(:validate_url)
        validator.no_clean = true
        validator.validate
        validator.validation_dir.should.exist
      end

      it 'builds the pod per platform' do
        file = write_podspec(stub_podspec)
        validator = Validator.new(file, SourcesManager.master.map(&:url))
        validator.stubs(:validate_url)
        validator.expects(:install_pod).times(3)
        validator.expects(:build_pod).times(3)
        validator.expects(:check_file_patterns).times(3)
        validator.validate
      end

      it 'builds the pod only once if the first fails with fail_fast' do
        Validator.any_instance.unstub(:xcodebuild)
        validator = Validator.new(podspec_path, SourcesManager.master.map(&:url))
        validator.stubs(:check_file_patterns)
        validator.stubs(:validate_url)
        validator.fail_fast = true
        validator.expects(:xcodebuild).once.returns('file.m:1:1: error: Pretended!')
        validator.validate
        validator.result_type.should == :error
      end

      it 'uses the deployment target of the specification' do
        validator = Validator.new(podspec_path, SourcesManager.master.map(&:url))
        validator.stubs(:validate_url)
        validator.stubs(:validate_screenshots)
        podfile = validator.send(:podfile_from_spec, :ios, '5.0')
        dependency = podfile.target_definitions['Pods'].dependencies.first
        dependency.external_source.key?(:podspec).should.be.true
      end

      it 'uses the deployment target of the current subspec' do
        validator = Validator.new(podspec_path, SourcesManager.master.map(&:url))
        validator.instance_variable_set(:@results, [])
        validator.stubs(:validate_url)
        validator.stubs(:validate_screenshots)
        validator.stubs(:check_file_patterns)
        validator.stubs(:check_file_patterns)
        validator.stubs(:install_pod)
        %i(prepare resolve_dependencies download_dependencies).each do |m|
          Installer.any_instance.stubs(m)
        end
        Installer.any_instance.stubs(:aggregate_targets).returns([])
        Installer.any_instance.stubs(:pod_targets).returns([])
        subspec = Specification.new(validator.spec, 'subspec') do |s|
          s.ios.deployment_target = '7.0'
        end
        validator.spec.stubs(:subspecs).returns([subspec])
        validator.expects(:podfile_from_spec).with(:osx, nil, nil).once
        validator.expects(:podfile_from_spec).with(:ios, nil, nil).once
        validator.expects(:podfile_from_spec).with(:ios, '7.0', nil).once
        validator.expects(:podfile_from_spec).with(:watchos, nil, nil).once
        validator.send(:perform_extensive_analysis, validator.spec)
      end

      describe '#podfile_from_spec' do
        before do
          @validator = Validator.new(podspec_path, SourcesManager.master.map(&:url))
          @validator.stubs(:validate_url)
        end

        it 'configures the deployment target' do
          podfile = @validator.send(:podfile_from_spec, :ios, '5.0')
          target_definition = podfile.target_definitions['Pods']
          platform = target_definition.platform
          platform.symbolic_name.should == :ios
          platform.deployment_target.to_s.should == '5.0'
        end

        it 'includes the use_frameworks! directive' do
          podfile = @validator.send(:podfile_from_spec, :ios, '5.0', true)
          target_definition = podfile.target_definitions['Pods']
          target_definition.uses_frameworks?.should == true
        end

        it 'includes the use_frameworks!(false) directive' do
          podfile = @validator.send(:podfile_from_spec, :ios, '5.0', false)
          target_definition = podfile.target_definitions['Pods']
          # rubocop:disable Style/DoubleNegation
          (!!target_definition.uses_frameworks?).should == false
          # rubocop:enable Style/DoubleNegation
        end
      end

      it 'repects the source_urls parameter' do
        sources = %w(master https://github.com/CocoaPods/Specs.git)
        Command::Repo::Add.any_instance.stubs(:run)
        validator = Validator.new(podspec_path, sources)
        validator.stubs(:validate_url)
        podfile = validator.send(:podfile_from_spec, :ios, '5.0')
        podfile.sources.should == %w(https://github.com/CocoaPods/Specs.git)
      end

      it 'uses xcodebuild to generate warnings' do
        validator = Validator.new(podspec_path, SourcesManager.master.map(&:url))
        validator.stubs(:check_file_patterns)
        validator.stubs(:xcodebuild).returns("file.m:1:1: warning: 'dataFromPropertyList:format:errorDescription:' is deprecated: first deprecated in iOS 8.0 - Use dataWithPropertyList:format:options:error: instead. [-Wdeprecated-declarations]")
        validator.stubs(:validate_url)
        validator.validate
        first = validator.results.map(&:to_s).first
        first.should.include '[xcodebuild]'
        validator.result_type.should == :warning
      end

      it 'uses xcodebuild to generate notes' do
        validator = Validator.new(podspec_path, SourcesManager.master.map(&:url))
        validator.stubs(:check_file_patterns)
        validator.stubs(:xcodebuild).returns("file.m:1:1: note: 'dataFromPropertyList:format:errorDescription:' has been explicitly marked deprecated here")
        validator.stubs(:validate_url)
        validator.validate
        first = validator.results.map(&:to_s).first
        first.should.include '[xcodebuild]'
        validator.result_type.should == :note
      end

      it 'checks if xcodebuild returns a successful status code' do
        Validator.any_instance.unstub(:xcodebuild)
        validator = Validator.new(podspec_path, SourcesManager.master.map(&:url))
        validator.stubs(:check_file_patterns)
        validator.stubs(:validate_url)
        git = Executable.which(:git)
        Executable.stubs(:which).with('git').returns(git)
        Executable.expects(:which).with('xcodebuild').times(3).returns('/usr/bin/xcodebuild')
        status = mock
        status.stubs(:success?).returns(false)
        validator.stubs(:_xcodebuild).returns(['Output', status])
        validator.validate
        first = validator.results.map(&:to_s).first
        first.should.include '[xcodebuild] Returned an unsuccessful exit code'
        validator.result_type.should == :error
      end

      it 'runs xcodebuild with correct arguments for code signing' do
        Validator.any_instance.unstub(:xcodebuild)
        validator = Validator.new(podspec_path, SourcesManager.master.map(&:url))
        validator.stubs(:check_file_patterns)
        validator.stubs(:validate_url)
        git = Executable.which(:git)
        Executable.stubs(:which).with('git').returns(git)
        Executable.expects(:which).with('xcodebuild').times(3).returns('/usr/bin/xcodebuild')
        command = 'xcodebuild clean build -target Pods'
        validator.expects(:`).with("#{command} 2>&1").twice.returns('')
        validator.expects(:`).with("#{command} CODE_SIGN_IDENTITY=- -sdk iphonesimulator 2>&1").once.returns('')
        validator.validate
      end

      it 'does filter InputFile errors completely' do
        validator = Validator.new(podspec_path, SourcesManager.master.map(&:url))
        validator.stubs(:check_file_patterns)
        validator.stubs(:xcodebuild).returns("2014-10-01 06:27:36.693 xcodebuild[61207:2007] error: InputFile    Target Support Files/Pods-OneUpFoundation/Pods-OneUpFoundation-prefix.pch 0 1412159238 77 33188... malformed line 10; 'InputFile' should have exactly five arguments")
        validator.stubs(:validate_url)
        validator.validate
        validator.results.count.should == 0
      end

      it 'does filter embedded frameworks warnings' do
        validator = Validator.new(podspec_path, SourcesManager.master.map(&:url))
        validator.stubs(:check_file_patterns)
        validator.stubs(:xcodebuild).returns('ld: warning: embedded dylibs/frameworks only run on iOS 8 or later.')
        validator.stubs(:validate_url)
        validator.validate
        validator.results.count.should == 0
      end

      describe 'file pattern validation' do
        it 'checks for file patterns' do
          file = write_podspec(stub_podspec(/.*source_files.*/, '"source_files": "wrong_paht.*",'))
          validator = Validator.new(file, SourcesManager.master.map(&:url))
          validator.stubs(:build_pod)
          validator.stubs(:validate_url)
          validator.validate
          validator.results.map(&:to_s).first.should.match /source_files.*did not match/
          validator.result_type.should == :error
        end

        it 'checks private_header_files matches only headers' do
          file = write_podspec(stub_podspec(/.*source_files.*/, '"source_files": "JSONKit.*", "private_header_files": "JSONKit.m",'))
          validator = Validator.new(file, SourcesManager.master.map(&:url))
          validator.stubs(:build_pod)
          validator.stubs(:validate_url)
          validator.validate
          validator.results.map(&:to_s).first.should.match /matches non-header files \(JSONKit\.m\)/
          validator.result_type.should == :error
        end

        it 'checks public_header_files matches only headers' do
          file = write_podspec(stub_podspec(/.*source_files.*/, '"source_files": "JSONKit.*", "public_header_files": "JSONKit.m",'))
          validator = Validator.new(file, SourcesManager.master.map(&:url))
          validator.stubs(:build_pod)
          validator.stubs(:validate_url)
          validator.validate
          validator.results.map(&:to_s).first.should.match /matches non-header files \(JSONKit\.m\)/
          validator.result_type.should == :error
        end

        it 'checks presence of license file' do
          file = write_podspec(stub_podspec(/.*license.*$/, '"license": "MIT",'))
          validator = Validator.new(file, SourcesManager.master.map(&:url))
          validator.stubs(:build_pod)
          validator.stubs(:validate_url)
          validator.validate
          validator.results.map(&:to_s).first.should.match /Unable to find a license file/
          validator.result_type.should == :warning
        end

        it 'checks module_map must exist if specified' do
          file = write_podspec(stub_podspec(/.*source_files.*/, '"source_files": "JSONKit.*", "module_map": "JSONKit.modulemap",'))
          validator = Validator.new(file, SourcesManager.master.map(&:url))
          validator.stubs(:build_pod)
          validator.stubs(:validate_url)
          validator.validate
          validator.results.map(&:to_s).first.should.match /Unable to find the specified module map file./
          validator.result_type.should == :error
        end

        it 'checks module_map accepts only modulemaps' do
          file = write_podspec(stub_podspec(/.*source_files.*/, '"source_files": "JSONKit.*", "module_map": "JSONKit.m",'))
          validator = Validator.new(file, SourcesManager.master.map(&:url))
          validator.stubs(:build_pod)
          validator.stubs(:validate_url)
          validator.validate
          validator.results.map(&:to_s).first.should.match /Unexpected file extension for modulemap file \(JSONKit\.m\)/
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
        validator = Validator.new(spec, SourcesManager.master.map(&:url))
        validator.stubs(:validate_url)
        validator.stubs(:build_pod)
        validator.validate
        validator.validated?.should.be.true
      end
    end

    describe 'frameworks' do
      before do
        @validator = Validator.new(podspec_path, SourcesManager.master.map(&:url))
      end

      def setup_validator
        @validator.instance_variable_set(:@results, [])
        @validator.stubs(:validate_url)
        @validator.stubs(:validate_screenshots)
        @validator.stubs(:check_file_patterns)
        @validator.stubs(:install_pod)
        %i(prepare resolve_dependencies download_dependencies).each do |m|
          Installer.any_instance.stubs(m)
        end
        Installer.any_instance.stubs(:aggregate_targets).returns([])
        Installer.any_instance.stubs(:pod_targets).returns([])
      end

      it 'lints as a framework if specified' do
        @validator.use_frameworks = true

        setup_validator

        @validator.expects(:podfile_from_spec).with(:osx, nil, true).once
        @validator.expects(:podfile_from_spec).with(:ios, nil, true).once
        @validator.expects(:podfile_from_spec).with(:watchos, nil, true).once
        @validator.send(:perform_extensive_analysis, @validator.spec)
      end

      it 'lint as a static library if specified' do
        @validator.use_frameworks = false

        setup_validator

        @validator.expects(:podfile_from_spec).with(:osx, nil, false).once
        @validator.expects(:podfile_from_spec).with(:ios, nil, false).once
        @validator.expects(:podfile_from_spec).with(:watchos, nil, false).once
        @validator.send(:perform_extensive_analysis, @validator.spec)
      end
    end

    describe 'dynamic binaries validation' do
      it 'fails with dynamic binaries on iOS < 8' do
        podspec = stub_podspec(/.*license.*$/, '"license": "Public Domain",')
        file = write_podspec(podspec)

        Pod::Sandbox::FileAccessor.any_instance.stubs(:vendored_libraries).returns([fixture('empty.dylib')])
        validator = Validator.new(file, SourcesManager.master.map(&:url))
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

        Podfile::TargetDefinition.any_instance.stubs(:uses_frameworks?).returns(true)
        Pod::Sandbox::FileAccessor.any_instance.stubs(:source_files).returns([Pathname.new('/Foo.swift')])
        validator = Validator.new(file, SourcesManager.master.map(&:url))
        validator.stubs(:build_pod)
        validator.stubs(:validate_url)
        validator.validate
        validator
      end

      it 'fails on deployment target < iOS 8 for Swift Pods' do
        validator = test_swiftpod

        validator.results.map(&:to_s).first.should.match /dynamic frameworks.*iOS > 8/
        validator.result_type.should == :error
      end

      it 'succeeds on deployment target < iOS 8 for Swift Pods using XCTest' do
        Specification::Consumer.any_instance.stubs(:frameworks).returns(%w(XCTest))

        validator = test_swiftpod
        validator.results.count.should == 0
      end

      it 'succeeds on deployment targets >= iOS 8 for Swift Pods' do
        Specification.any_instance.stubs(:deployment_target).returns('9.0')

        validator = test_swiftpod

        validator.results.count.should == 0
      end
    end
    #-------------------------------------------------------------------------#
  end
end
