require File.expand_path('../../spec_helper', __FILE__)

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

    it "validates a correct podspec" do
      validator = Validator.new(podspec_path)
      validator.quick = true
      validator.validate
      validator.results.should == []
      validator.validated?.should.be.true
    end

    it "lints the podspec during validation" do
      podspec = stub_podspec(/s.name.*$/, 's.name = "TEST"')
      file = write_podspec(podspec)
      validator = Validator.new(file)
      validator.quick = true
      validator.validate
      validator.results.map(&:to_s).first.should.match /should match the name/
      validator.validated?.should.be.false
    end

    it "uses xcodebuild to generate notes and warnings" do
      validator = Validator.new(podspec_path)
      validator.stubs(:check_file_patterns)
      validator.stubs(:xcodebuild).returns("file.m:1:1: warning: direct access to objective-c's isa is deprecated")
      validator.validate
      first = validator.results.map(&:to_s).first
      first.should.include "[xcodebuild]"
      validator.result_type.should == :note
    end

    it "checks for file patterns" do
      file = write_podspec(stub_podspec(/s\.source_files = 'JSONKit\.\*'/, "s.source_files = 'wrong_paht.*'"))
      validator = Validator.new(file)
      validator.stubs(:build_pod)
      validator.validate
      validator.results.map(&:to_s).first.should.match /source_files.*did not match/
      validator.result_type.should == :error
    end

    it "validates a podspec with dependencies" do
      podspec = stub_podspec(/s.name.*$/, 's.name = "ZKit"')
      podspec.gsub!(/s.requires_arc/, "s.dependency 'SBJson', '~> 3.2'\n  s.requires_arc")
      podspec.gsub!(/s.license.*$/, 's.license = "Public Domain"')
      file = write_podspec(podspec, "ZKit.podspec")

      spec = Specification.from_file(file)
      validator = Validator.new(spec)
      validator.validate
      validator.validated?.should.be.true
    end

    #--------------------------------------#

    it "respects quick mode" do
      file = write_podspec(stub_podspec)
      validator = Validator.new(file)
      validator.quick = true
      validator.expects(:perform_extensive_analysis).never
      validator.validate
    end

    it "respects the no clean option" do
      file = write_podspec(stub_podspec)
      validator = Validator.new(file)
      validator.no_clean = true
      validator.validate
      validator.validation_dir.should.exist
    end

    it "respects the local option" do
      validator = Validator.new(podspec_path)
      podfile = validator.send(:podfile_from_spec, :ios, '5.0')
      deployment_target = podfile.target_definitions['Pods'].platform.deployment_target
      deployment_target.to_s.should == "5.0"
    end

    it "respects the only errors option" do
      podspec = stub_podspec(/s.summary.*/, "s.summary = 'A short description of'")
      file = write_podspec(podspec)
      validator = Validator.new(file)
      validator.quick = true
      validator.only_errors = true
      validator.validate
      validator.results.map(&:to_s).first.should.match /summary.*meaningful/
      validator.validated?.should.be.true
    end

    it "uses the deployment target of the specification" do
      validator = Validator.new(podspec_path)
      podfile = validator.send(:podfile_from_spec, :ios, '5.0')
      dependency = podfile.target_definitions['Pods'].dependencies.first
      dependency.external_source.has_key?(:podspec).should.be.true
    end
  end
end
