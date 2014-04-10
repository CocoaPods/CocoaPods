require File.expand_path('../../spec_helper', __FILE__)
require 'webmock'

module Bacon
  class Context
    alias_method :after_webmock, :after
    def after(&block)
      after_webmock do
        block.call()
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
    def write_podspec(text, name = 'JSONKit.podspec')
      file = temporary_directory + name
      File.open(file, 'w') {|f| f.write(text) }
      file
    end

    # @return [String]
    #
    def stub_podspec(pattern = nil, replacement = nil)
      spec = (fixture('spec-repos') + 'master/JSONKit/1.4/JSONKit.podspec').read
      spec.gsub!(/https:\/\/github\.com\/johnezang\/JSONKit\.git/, fixture('integration/JSONKit').to_s)
      spec.gsub!(pattern, replacement) if pattern && replacement
      spec
    end

    # @return [Pathname]
    #
    def podspec_path
      fixture('spec-repos') + 'master/JSONKit/1.4/JSONKit.podspec'
    end

    #-------------------------------------------------------------------------#

    describe "Quick mode" do
      it "validates a correct podspec" do
        sut = Validator.new(podspec_path)
        sut.quick = true
        sut.validate
        sut.results.should == []
        sut.validated?.should.be.true
      end

      it "lints the podspec during validation" do
        podspec = stub_podspec(/s.name.*$/, 's.name = "TEST"')
        file = write_podspec(podspec)
        sut = Validator.new(file)
        sut.quick = true
        sut.validate
        sut.results.map(&:to_s).first.should.match /should match the name/
        sut.validated?.should.be.false
      end

      it "respects quick mode" do
        file = write_podspec(stub_podspec)
        sut = Validator.new(file)
        sut.quick = true
        sut.expects(:perform_extensive_analysis).never
        sut.validate
      end

      it "respects the only errors option" do
        podspec = stub_podspec(/s.summary.*/, "s.summary = 'A short description of'")
        file = write_podspec(podspec)
        sut = Validator.new(file)
        sut.quick = true
        sut.only_errors = true
        sut.validate
        sut.results.map(&:to_s).first.should.match /summary.*meaningful/
        sut.validated?.should.be.true
      end

      it "handles symlinks" do
        file = write_podspec(stub_podspec)
        validator = Validator.new(file)
        validator.quick = true
        validator.stubs(:validate_urls)
        validator.validate
        validator.validation_dir.should.be == Pathname.new("/private/tmp/CocoaPods/Lint")
      end
    end

    #-------------------------------------------------------------------------#

    describe "Extensive analysis" do

      describe "URL validation" do
        before do
          @sut = Validator.new(podspec_path)
          @sut.stubs(:install_pod)
          @sut.stubs(:build_pod)
          @sut.stubs(:check_file_patterns)
          @sut.stubs(:tear_down_validation_environment)
        end

        describe "Homepage validation" do
          it "checks if the homepage is valid" do
            WebMock::API.stub_request(:head, /not-found/).to_return(:status => 404)
            Specification.any_instance.stubs(:homepage).returns('http://banana-corp.local/not-found/')
            @sut.validate
            @sut.results.map(&:to_s).first.should.match /The URL (.*) is not reachable/
          end

          it "indicates if it was not able to validate the homepage" do
            WebMock::API.stub_request(:head, 'banana-corp.local').to_raise(SocketError)
            Specification.any_instance.stubs(:homepage).returns('http://banana-corp.local/')
            @sut.validate
            @sut.results.map(&:to_s).first.should.match /There was a problem validating the URL/
          end
        end

        describe "Screenshot validation" do
          before do
            @sut.stubs(:validate_homepage)
            WebMock::API.stub_request(:head, 'banana-corp.local/valid-image.png').to_return(:status => 200, :headers => { 'Content-Type' => 'image/png' })
          end

          it "checks if the screenshots are valid" do
            Specification.any_instance.stubs(:screenshots).returns(['http://banana-corp.local/valid-image.png'])
            @sut.validate
            @sut.results.should.be.empty?
          end

          it "should fail if any of the screenshots URLS do not return an image" do
            WebMock::API.stub_request(:head, 'banana-corp.local/').to_return(:status => 200)
            Specification.any_instance.stubs(:screenshots).returns(['http://banana-corp.local/valid-image.png', 'http://banana-corp.local/'])
            @sut.validate
            @sut.results.map(&:to_s).first.should.match /The screenshot .* is not a valid image/
          end
        end

        describe "documentation URL validation" do
          before do
            @sut.stubs(:validate_homepage)
          end

          it "checks if the documentation URL is valid" do
            Specification.any_instance.stubs(:documentation_url).returns('http://banana-corp.local/')
            WebMock::API.stub_request(:head, /banana-corp.local/).to_return(:status => 200)
            @sut.validate
            @sut.results.should.be.empty?
          end

          it "should fail validation if it wasn't able to validate the URL" do
            Specification.any_instance.stubs(:documentation_url).returns('http://banana-corp.local/')
            WebMock::API.stub_request(:head, /banana-corp.local/).to_return(:status => 404)
            @sut.validate
            @sut.results.map(&:to_s).first.should.match /The URL (.*) is not reachable/
          end
        end

        describe "docset URL validation" do
          before do
            @sut.stubs(:validate_homepage)
          end

          it "checks if the docset URL is valid" do
            Specification.any_instance.stubs(:docset_url).returns('http://banana-corp.local/')
            WebMock::API.stub_request(:head, /banana-corp.local/).to_return(:status => 200)
            @sut.validate
            @sut.results.should.be.empty?
          end

          it "should fail validation if it wasn't able to validate the URL" do
            Specification.any_instance.stubs(:docset_url).returns('http://banana-corp.local/')
            WebMock::API.stub_request(:head, /banana-corp.local/).to_return(:status => 404)
            @sut.validate
            @sut.results.map(&:to_s).first.should.match /The URL (.*) is not reachable/
          end
        end

        describe "social media URL validation" do
          before do
            @sut.stubs(:validate_homepage)
          end

          it "checks if the social media URL is valid" do
            Specification.any_instance.stubs(:social_media_urlon_url).returns('http://banana-corp.local/')
            WebMock::API.stub_request(:head, /banana-corp.local/).to_return(:status => 200)
            @sut.validate
            @sut.results.should.be.empty?
          end

          it "should fail validation if it wasn't able to validate the URL" do
            Specification.any_instance.stubs(:social_media_url).returns('http://banana-corp.local/')
            WebMock::API.stub_request(:head, /banana-corp.local/).to_return(:status => 404)
            @sut.validate
            @sut.results.map(&:to_s).first.should.match /The URL (.*) is not reachable/
          end
        end
      end

      it "respects the no clean option" do
        file = write_podspec(stub_podspec)
        sut = Validator.new(file)
        sut.stubs(:validate_urls)
        sut.no_clean = true
        sut.validate
        sut.validation_dir.should.exist
      end

      it "builds the pod per platform" do
        file = write_podspec(stub_podspec)
        sut = Validator.new(file)
        sut.stubs(:validate_urls)
        sut.expects(:install_pod).twice
        sut.expects(:build_pod).twice
        sut.expects(:check_file_patterns).twice
        sut.validate
      end

      it "uses the deployment target of the specification" do
        sut = Validator.new(podspec_path)
        sut.stubs(:validate_urls)
        podfile = sut.send(:podfile_from_spec, :ios, '5.0')
        dependency = podfile.target_definitions['Pods'].dependencies.first
        dependency.external_source.has_key?(:podspec).should.be.true
      end

      it "respects the local option" do
        sut = Validator.new(podspec_path)
        sut.stubs(:validate_urls)
        podfile = sut.send(:podfile_from_spec, :ios, '5.0')
        deployment_target = podfile.target_definitions['Pods'].platform.deployment_target
        deployment_target.to_s.should == "5.0"
      end

      it "uses xcodebuild to generate notes and warnings" do
        sut = Validator.new(podspec_path)
        sut.stubs(:check_file_patterns)
        sut.stubs(:xcodebuild).returns("file.m:1:1: warning: direct access to objective-c's isa is deprecated")
        sut.stubs(:validate_urls)
        sut.validate
        first = sut.results.map(&:to_s).first
        first.should.include "[xcodebuild]"
        sut.result_type.should == :note
      end

      it "checks for file patterns" do
        file = write_podspec(stub_podspec(/s\.source_files = 'JSONKit\.\*'/, "s.source_files = 'wrong_paht.*'"))
        sut = Validator.new(file)
        sut.stubs(:build_pod)
        sut.stubs(:validate_urls)
        sut.validate
        sut.results.map(&:to_s).first.should.match /source_files.*did not match/
        sut.result_type.should == :error
      end

      it "validates a podspec with dependencies" do
        podspec = stub_podspec(/s.name.*$/, 's.name = "ZKit"')
        podspec.gsub!(/s.requires_arc/, "s.dependency 'SBJson', '~> 3.2'\n  s.requires_arc")
        podspec.gsub!(/s.license.*$/, 's.license = "Public Domain"')
        file = write_podspec(podspec, "ZKit.podspec")

        spec = Specification.from_file(file)
        sut = Validator.new(spec)
        sut.stubs(:validate_urls)
        sut.stubs(:build_pod)
        sut.validate
        sut.validated?.should.be.true
      end
    end
    #-------------------------------------------------------------------------#

  end
end
