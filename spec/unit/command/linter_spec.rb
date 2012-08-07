require File.expand_path('../../../spec_helper', __FILE__)

describe "Pod::Command::Linter" do
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

  it "fails a specifications that does not contain the minimum required attributes" do
    file = write_podspec('Pod::Spec.new do |s| end')
    linter = Pod::Command::Spec::Linter.new(file)
    linter.quick = true
    linter.lint
    linter.result_type.should == :error
    linter.errors.join(' | ') =~ /name.*version.*summary.*homepage.*authors.*(source.*part_of).*source_files/
  end

  it "fails specifications if the name does not match the name of the file" do
    file = write_podspec(stub_podspec(/s.name *= 'JSONKit'/, "s.name = 'JSONKitAAA'"))
    linter = Pod::Command::Spec::Linter.new(file)
    linter.quick = true
    linter.lint
    linter.result_type.should == :error
    linter.errors.count.should == 1
    linter.errors[0].should =~ /The name of the spec should match the name of the file/
  end

  it "fails a specification if a path starts with a slash" do
    file = write_podspec(stub_podspec(/s.source_files = 'JSONKit\.\*'/, "s.source_files = '/JSONKit.*'"))
    linter = Pod::Command::Spec::Linter.new(file)
    linter.quick = true
    linter.lint
    linter.result_type.should == :error
    linter.errors.count.should == 1
    linter.errors[0].should =~ /Paths cannot start with a slash/
  end

  it "fails a specification if the platform is unrecognized" do
    file = write_podspec(stub_podspec(/s.name *= 'JSONKit'/, "s.name = 'JSONKit'\ns.platform = :iososx\n"))
    linter = Pod::Command::Spec::Linter.new(file)
    linter.quick = true
    linter.lint
    linter.result_type.should == :error
    linter.errors.count.should == 1
    linter.errors[0].should =~ /Unrecognized platfrom/
  end

  it "fails validation if the specification contains warnings" do
    file = write_podspec(stub_podspec(/.*license.*/, ""))
    linter = Pod::Command::Spec::Linter.new(file)
    linter.quick = true
    linter.lint
    linter.result_type.should == :warning
    linter.errors.should.be.empty
    linter.warnings.should.not.be.empty
  end

  it "correctly report specification that only contain warnings" do
    file = write_podspec(stub_podspec(/.*license.*/, ""))
    linter = Pod::Command::Spec::Linter.new(file)
    linter.quick = true
    linter.lint
    linter.result_type.should == :warning
  end

  it "respects quick mode" do
    file = write_podspec(stub_podspec)
    linter = Pod::Command::Spec::Linter.new(file)
    linter.expects(:peform_multiplatform_analysis).never
    linter.expects(:install_pod).never
    linter.expects(:xcodebuild_output_for_platfrom).never
    linter.expects(:file_patterns_errors_for_platfrom).never
    linter.quick = true
    linter.lint
  end

  it "produces deprecation notices" do
    file = write_podspec(stub_podspec(/s\.source_files = 'JSONKit\.\*'/, "s.source_files = 'JSONKit.*'\n if config.ios?\nend"))
    linter = Pod::Command::Spec::Linter.new(file)
    linter.quick = true
    linter.lint
    linter.result_type.should == :error
    linter.warnings.should.be.empty
    linter.errors.join(' | ').should =~ /`config.ios\?' and `config.osx\?' are deprecated/
  end

  it "uses xcodebuild to generate notes and warnings" do
    file = write_podspec(stub_podspec)
    linter = Pod::Command::Spec::Linter.new(file)
    linter.lint
    linter.result_type.should == :warning
    linter.notes.join(' | ').should.include "JSONKit/JSONKit.m:1640:27: warning: equality comparison with extraneous parentheses" unless `which xcodebuild`.strip.empty?
  end

  it "checks for file patterns" do
    file = write_podspec(stub_podspec(/s\.source_files = 'JSONKit\.\*'/, "s.source_files = 'JSONKit.*'\ns.resources = 'WRONG_FOLDER'"))
    linter = Pod::Command::Spec::Linter.new(file)
    linter.stubs(:xcodebuild_output).returns([])
    linter.quick = false
    linter.lint
    linter.result_type.should == :error
    linter.errors.join(' | ').should.include "The resources did not match any file"
  end

  it "uses the deployment target of the specification" do
    file = write_podspec(stub_podspec(/s.name *= 'JSONKit'/, "s.name = 'JSONKit'; s.platform = :ios, '5.0'"))
    linter = Pod::Command::Spec::Linter.new(file)
    linter.quick = true
    linter.lint
    podfile = linter.podfile_from_spec
    deployment_target = podfile.target_definitions[:default].platform.deployment_target
    deployment_target.to_s.should == "5.0"
  end
end

