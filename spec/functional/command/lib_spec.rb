require File.expand_path('../../../spec_helper', __FILE__)

module Pod

  describe Command::Lib::Create do

    before do
      @sut = Command::Lib::Create
    end

    it "complains if wrong parameters" do
      lambda { run_command('lib', 'create') }.should.raise CLAide::Help
    end

    it "complains if pod name contains spaces" do
      lambda { run_command('lib', 'create', 'Pod Name With Spaces') }.should.raise CLAide::Help
    end

    it "should create a new dir for the newly created pod" do
      @sut.any_instance.stubs(:configure_template)
      url = @sut::TEMPLATE_REPO
      @sut.any_instance.expects(:git!).with("clone '#{url}' TestPod").once
      run_command('lib', 'create', 'TestPod')
    end

    it "configures the template after cloning it passing the name of the Pod as the argument" do
      @sut.any_instance.stubs(:clone_template)
      dir = SpecHelper.temporary_directory + 'TestPod'
      dir.mkpath
      File.stubs(:exists?).with("configure").returns(true)
      @sut.any_instance.expects(:system).with("./configure TestPod").once
      run_command('lib', 'create', 'TestPod')
    end

    it "should show link to new pod guide after creation" do
      @sut.any_instance.stubs(:clone_template)
      @sut.any_instance.stubs(:configure_template)
      output = run_command('lib', 'create', 'TestPod')
      output.should.include? 'http://guides.cocoapods.org/making/making-a-cocoapod'
    end

    before do
      @sut.any_instance.stubs(:configure_template)
    end

    it "should use the given template URL" do
      template_url = 'https://github.com/custom/template.git'
      @sut.any_instance.expects(:git!).with("clone '#{template_url}' TestPod").once
      sut = run_command('lib', 'create', 'TestPod', template_url)
    end

    it "should use the default URL if no template URL is given" do
      template_url = 'https://github.com/CocoaPods/pod-template.git'
      @sut.any_instance.expects(:git!).with("clone '#{template_url}' TestPod").once
      run_command('lib', 'create', 'TestPod')
    end
  end

  describe Command::Lib::Lint do
    it "lints the current working directory" do
        Dir.chdir(fixture('integration/Reachability')) do
          cmd = command('lib', 'lint', '--only-errors', '--quick')
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
          Validator.any_instance.expects(:no_clean=).with(false)
          Validator.any_instance.stubs(:perform_extensive_analysis)
          should.raise Pod::Informative do
            run_command('lib', 'lint', 'Broken.podspec')
          end
          UI.output.should.include "Missing required attribute"
        end
    end

    it "fails to lint a broken spec file and leaves lint directory" do
        Dir.chdir(temporary_directory) do
          open(temporary_directory + 'Broken.podspec', 'w') { |f|
            f << 'Pod::Spec.new do |spec|'
            f << "spec.name         = 'Broken'"
            f << 'end'
          }
          Validator.any_instance.expects(:no_clean=).with(true)
          Validator.any_instance.stubs(:perform_extensive_analysis)
          should.raise Pod::Informative do
            run_command('lib', 'lint', 'Broken.podspec', '--no-clean')
          end
          UI.output.should.include "Missing required attribute"
          UI.output.should.include "Pods project available at"
        end
    end
  end
end
