require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Validator do
    extend SpecHelper::TemporaryDirectory

    # @return [void]
    #
    def write_podspec(text, name = 'JSONKit.podspec')
      file = temporary_directory + 'JSONKit.podspec'
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
      validator.repo_path = fixture('spec-repos/master')
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

    it "checks the path of the specification if a repo path is provided" do
      validator = Validator.new(podspec_path)
      validator.quick = true
      validator.repo_path = fixture('.')
      validator.validate
      validator.results.map(&:to_s).first.should.match /Incorrect path/
      validator.validated?.should.be.false
    end

    unless skip_xcodebuild?
      it "uses xcodebuild to generate notes and warnings" do
        validator = Validator.new(podspec_path)
        validator.stubs(:check_file_patterns)
        validator.validate
        first = validator.results.map(&:to_s).first
        first.should.include "[NOTE] XCODEBUILD"
        first.should.include "JSONKit/JSONKit.m:1640:27: warning: equality comparison"
        first.should.include "[OS X - iOS]"
        validator.result_type.should == :note
      end
    end

    it "checks for file patterns" do
      file = write_podspec(stub_podspec(/s\.source_files = 'JSONKit\.\*'/, "s.source_files = 'wrong_paht.*'"))
      validator = Validator.new(file)
      validator.stubs(:build_pod)
      validator.validate
      validator.results.map(&:to_s).first.should.match /source_files.*did not match/
      validator.result_type.should == :error
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
      podfile = validator.send(:podfile_from_spec, Platform.new(:ios, '5.0'))
      deployment_target = podfile.target_definitions[:default].platform.deployment_target
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
      podfile = validator.send(:podfile_from_spec, Platform.new(:ios, '5.0'))
      dependency = podfile.target_definitions[:default].dependencies.first
      dependency.external_source.has_key?(:podspec).should.be.true
    end
  end
end
