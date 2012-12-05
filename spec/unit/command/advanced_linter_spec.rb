require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::AdvancedLinter do
    extend SpecHelper::TemporaryDirectory

    def write_podspec(text, name = 'JSONKit.podspec')
      file = temporary_directory + 'JSONKit.podspec'
      File.open(file, 'w') {|f| f.write(text) }
      file
    end

    def stub_podspec(pattern = nil, replacement = nil)
      spec = (fixture('spec-repos') + 'master/JSONKit/1.4/JSONKit.podspec').read
      spec.gsub!(/https:\/\/github\.com\/johnezang\/JSONKit\.git/, fixture('integration/JSONKit').to_s)
      spec.gsub!(pattern, replacement) if pattern && replacement
      spec
    end

    it "respects quick mode" do
      file = write_podspec(stub_podspec)
      linter = Command::AdvancedLinter.new(file)
      linter.expects(:peform_multiplatform_analysis).never
      linter.expects(:install_pod).never
      linter.expects(:xcodebuild_output_for_platfrom).never
      linter.expects(:file_patterns_errors_for_platfrom).never
      linter.quick = true
      linter.lint
    end

    unless skip_xcodebuild?
      it "uses xcodebuild to generate notes and warnings" do
        file = write_podspec(stub_podspec)
        linter = Command::AdvancedLinter.new(file)
        linter.lint
        linter.result_type.should == :warning
        linter.notes.join(' | ').should.include "JSONKit/JSONKit.m:1640:27: warning: equality comparison with extraneous parentheses"
      end
    end

    it "checks for file patterns" do
      file = write_podspec(stub_podspec(/s\.source_files = 'JSONKit\.\*'/, "s.source_files = 'JSONKit.*'\ns.resources = 'WRONG_FOLDER'"))
      linter = Command::AdvancedLinter.new(file)
      linter.stubs(:xcodebuild_output).returns([])
      linter.quick = false
      linter.lint
      linter.result_type.should == :error
      linter.errors.join(' | ').should.include "The resources did not match any file"
    end

    it "uses the deployment target of the specification" do
      file = write_podspec(stub_podspec(/s.name *= 'JSONKit'/, "s.name = 'JSONKit'; s.platform = :ios, '5.0'"))
      linter = Command::AdvancedLinter.new(file)
      linter.quick = true
      linter.lint
      podfile = linter.podfile_from_spec
      deployment_target = podfile.target_definitions[:default].platform.deployment_target
      deployment_target.to_s.should == "5.0"
    end
  end
end
