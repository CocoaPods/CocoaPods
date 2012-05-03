require File.expand_path('../../../spec_helper', __FILE__)

describe "Pod::Command::Spec::Linter" do
  extend SpecHelper::TemporaryDirectory

  def write_podspec(text, name = 'JSONKit.podspec')
    file = temporary_directory + 'JSONKit.podspec'
    File.open(file, 'w') {|f| f.write(text) }
    spec = Pod::Specification.from_file(file)
    [spec, file]
  end

  def stub_podspec(pattern = nil, replacement = nil)
    spec = (fixture('spec-repos') + 'master/JSONKit/1.4/JSONKit.podspec').read
    spec.gsub!(/https:\/\/github\.com\/johnezang\/JSONKit\.git/, fixture('integration/JSONKit').to_s)
    spec.gsub!(pattern, replacement) if pattern && replacement
    spec
  end

  it "fails a specifications that does not contain the minimum required attributes" do
    spec, file = write_podspec('Pod::Spec.new do |s| end')
    linter = Pod::Command::Spec::Linter.new(spec, file)
    linter.lenient, linter.quick = true, true
    linter.lint.should == false
    linter.errors.join(' | ') =~ /name.*version.*summary.*homepage.*authors.*(source.*part_of).*source_files/
  end

  it "fails specifications if the name does not match the name of the file" do
    spec, file = write_podspec(stub_podspec(/s.name *= 'JSONKit'/, "s.name = 'JSONKitAAA'"))
    linter = Pod::Command::Spec::Linter.new(spec, file)
    linter.lenient, linter.quick = true, true
    linter.lint.should == false
    linter.errors.count.should == 1
    linter.errors[0].should =~ /The name of the spec should match the name of the file/
  end

  it "fails a specification if a path starts with a slash" do
    spec, file = write_podspec(stub_podspec(/s.source_files = 'JSONKit\.\*'/, "s.source_files = '/JSONKit.*'"))
    linter = Pod::Command::Spec::Linter.new(spec, file)
    linter.lenient, linter.quick = true, true
    linter.lint.should == false
    linter.errors.count.should == 1
    linter.errors[0].should =~ /Paths cannot start with a slash/
  end

  it "fails a specification if the plafrom is unrecognized" do
    spec, file = write_podspec(stub_podspec(/s.name *= 'JSONKit'/, "s.name = 'JSONKit'\ns.platform = :iososx\n"))
    linter = Pod::Command::Spec::Linter.new(spec, file)
    linter.lenient, linter.quick = true, true
    linter.lint.should == false
    linter.errors.count.should == 1
    linter.errors[0].should =~ /Unrecognized platfrom/
  end

  it "fails validation if the specification contains warnings" do
    spec, file = write_podspec(stub_podspec)
    linter = Pod::Command::Spec::Linter.new(spec, file)
    linter.lenient, linter.quick = false, true
    linter.lint.should == false
    linter.errors.should.be.empty
    linter.warnings.should.not.be.empty
  end

  it "validates in lenient mode if there are no erros but there are warnings" do
    spec, file = write_podspec(stub_podspec)
    linter = Pod::Command::Spec::Linter.new(spec, file)
    linter.lenient, linter.quick = true, true
    linter.lint.should == true
    linter.errors.should.be.empty
    linter.warnings.should.not.be.empty
  end

  it "respects quick mode" do
    spec, file = write_podspec(stub_podspec)
    linter = Pod::Command::Spec::Linter.new(spec, file)
    linter.expects(:peform_multiplatform_analysis).never
    linter.expects(:install_pod).never
    linter.expects(:xcodebuild_output_for_platfrom).never
    linter.expects(:file_patterns_errors_for_platfrom).never
    linter.lenient, linter.quick = false, true
    linter.lint
  end

  it "produces deprecation notices" do
    spec, file = write_podspec(stub_podspec(/s\.source_files = 'JSONKit\.\*'/, "s.source_files = 'JSONKit.*'\n if config.ios?\nend"))
    linter = Pod::Command::Spec::Linter.new(spec, file)
    linter.lenient, linter.quick = false, true
    linter.lint.should == false
    linter.errors.should.be.empty
    linter.warnings.join(' | ').should =~ /`config.ios\?' and `config.osx' will be removed in version 0.7/
  end

 it "uses xcodebuild to generate notes and warnings" do
    spec, file = write_podspec(stub_podspec)
    linter = Pod::Command::Spec::Linter.new(spec, file)
    linter.lenient, linter.quick = false, false
    linter.lint.should == false
    linter.notes.join(' | ').should.include "JSONKit/JSONKit.m:1640:27: warning: equality comparison with extraneous parentheses" unless `which xcodebuild`.strip.empty?
  end

 it "checks for file patterns" do
    spec, file = write_podspec(stub_podspec(/s\.source_files = 'JSONKit\.\*'/, "s.source_files = 'JSONKit.*'\ns.resources = 'WRONG_FOLDER'"))
    linter = Pod::Command::Spec::Linter.new(spec, file)
    linter.stubs(:xcodebuild_output_for_platfrom).returns([])
    linter.lenient, linter.quick = false, false
    linter.lint.should == false
    linter.errors.join(' | ').should.include "[resources = 'WRONG_FOLDER'] -> did not match any file"
  end
end
