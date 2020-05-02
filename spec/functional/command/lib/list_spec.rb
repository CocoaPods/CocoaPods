require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Command::Lib::Lint do
    it 'lints the current working directory' do
      Dir.chdir(fixture('integration/Reachability')) do
        cmd = command('lib', 'lint', '--only-errors', '--quick')
        cmd.run
        UI.output.should.include 'passed validation'
      end
    end

    it 'lints the current working directory using Debug configuration' do
      Dir.chdir(fixture('integration/Reachability')) do
        cmd = command('lib', 'lint', '--only-errors', '--quick', '--configuration=Debug')
        cmd.run
        UI.output.should.include 'passed validation'
      end
    end

    it 'lints a single spec in the current working directory' do
      Dir.chdir(fixture('integration/Reachability')) do
        cmd = command('lib', 'lint', 'Reachability.podspec', '--quick', '--only-errors')
        cmd.run
        UI.output.should.include 'passed validation'
      end
    end

    it 'fails to lint a broken spec file and cleans up' do
      Dir.chdir(temporary_directory) do
        open(temporary_directory + 'Broken.podspec', 'w') do |f|
          f << 'Pod::Spec.new do |spec|'
          f << "spec.name         = 'Broken'"
          f << 'end'
        end
        Validator.any_instance.expects(:no_clean=).with(false)
        Validator.any_instance.stubs(:perform_extensive_analysis)
        should.raise Pod::Informative do
          run_command('lib', 'lint', 'Broken.podspec')
        end
        UI.output.should.include 'Missing required attribute'
      end
    end

    it 'fails to lint a broken spec file and leaves lint directory' do
      Dir.chdir(temporary_directory) do
        open(temporary_directory + 'Broken.podspec', 'w') do |f|
          f << 'Pod::Spec.new do |spec|'
          f << "spec.name         = 'Broken'"
          f << 'end'
        end
        Validator.any_instance.expects(:no_clean=).with(true)
        Validator.any_instance.stubs(:perform_extensive_analysis)
        should.raise Pod::Informative do
          run_command('lib', 'lint', 'Broken.podspec', '--no-clean')
        end
        UI.output.should.include 'Missing required attribute'
        UI.output.should.include 'Pods workspace available at'
      end
    end

    it 'fails to lint if the spec is not loaded' do
      Dir.chdir(temporary_directory) do
        should.raise Pod::Informative do
          run_command('lib', 'lint', '404.podspec')
        end
        UI.output.should.include 'could not be loaded'
      end
    end
  end
end
