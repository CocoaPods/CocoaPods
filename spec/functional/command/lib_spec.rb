require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::Lib::Create do
    it "complains if wrong parameters" do
      lambda { run_command('lib', 'create') }.should.raise CLAide::Help
    end

    it "complains if pod name contains spaces" do
      lambda { run_command('lib', 'create', 'Pod Name With Spaces') }.should.raise CLAide::Help
    end
  end

  describe Command::Lib::Lint do
    it "lints the current working directory" do
        Dir.chdir(fixture('integration/Reachability')) do
          cmd = command('lib', 'lint', '--only-errors')
          cmd.run
          UI.output.should.include "passed validation"
        end
    end

    it "lints a single spec in the current working directory" do
        Dir.chdir(fixture('integration/Reachability')) do
          cmd = command('lib', 'lint', 'Reachability.podspec', '--quick', '--only-errors')
          cmd.run
          UI.output.should.include "passed validation"
        end
    end

    it "fails to lint a broken spec file and cleans up" do
        Dir.chdir(temporary_directory) do
          open(temporary_directory + 'Broken.podspec', 'w') { |f|
            f << 'Pod::Spec.new do |spec|'
            f << "spec.name         = 'Broken'"
            f << 'end'
          }
          tmp_validator = Validator.new('Broken.podspec')
          lint_path = tmp_validator.validation_dir

          lambda { run_command('lib', 'lint', 'Broken.podspec') }.should.raise Pod::Informative

          UI.output.should.include "Missing required attribute"

          lint_path.exist?.should == false
        end
    end

    it "fails to lint a broken spec file and leaves lint directory" do
        Dir.chdir(temporary_directory) do
          open(temporary_directory + 'Broken.podspec', 'w') { |f|
            f << 'Pod::Spec.new do |spec|'
            f << "spec.name         = 'Broken'"
            f << 'end'
          }
          lambda { run_command('lib', 'lint', 'Broken.podspec', '--no-clean') }.should.raise Pod::Informative

          UI.output.should.include "Pods project available at"
          UI.output.should.include "Missing required attribute"

          lint_dir = UI.output[/.*Pods project available at `(.*)` for inspection./,1]
          Pathname.new(lint_dir).exist?.should == true
        end
    end
  end

  describe Command::Lib do

    it "should create a new dir for the newly created pod" do
      run_command('lib', 'create', 'TestPod')
      Dir.chdir(temporary_directory) do
          Pathname.new(temporary_directory + 'TestPod').exist?.should == true
      end
    end

    it "should show link to new pod guide after creation" do
      output = run_command('lib', 'create', 'TestPod')
      output.should.include? 'http://guides.cocoapods.org/making/making-a-cocoapod'
    end

    before do
      Command::Lib::Create.any_instance.stubs(:configure_template)
      Command::Lib::Create.any_instance.stubs(:git!)
    end

    it "should use the given template URL" do
      template_url = 'https://github.com/custom/template.git'
      Command::Lib::Create.any_instance.expects(:git!).with("clone '#{template_url}' TestPod").once
      sut = run_command('lib', 'create', 'TestPod', template_url)
    end

    it "should use the default URL if no template URL is given" do
      template_url = 'https://github.com/CocoaPods/pod-template.git'
      Command::Lib::Create.any_instance.expects(:git!).with("clone '#{template_url}' TestPod").once
      run_command('lib', 'create', 'TestPod')
    end
  end
end
