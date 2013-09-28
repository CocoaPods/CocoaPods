require File.expand_path('../../../spec_helper', __FILE__)
require 'yaml'

module Pod
  describe Command::Config do
    extend SpecHelper::TemporaryRepos

    LOCAL_OVERRIDES = 'PER_PROJECT_REPO_OVERRIDES'
    GLOBAL_OVERRIDES = 'GLOBAL_REPO_OVERRIDES'
    pod_name = 'ObjectiveSugar'
    pod_path = '~/code/OSS/ObjectiveSugar'
    project_name = 'SampleProject'

    @config_file_path = temporary_directory + 'config.yaml'

    before do
      FileUtils.rm_rf(@config_file_path)
      @subject = Config::ConfigManager.new
      # TODO: stub the file accessor
    end

    it "writes local repos for each project" do
      run_command('config', "--local", pod_name, pod_path)
      yaml = YAML.load(File.open(@config_file_path))

      yaml[LOCAL_OVERRIDES][project_name][pod_name].should.equal pod_path
    end

    it "writes global repos without specifying project" do
      run_command('config', "--global", pod_name, pod_path)
      yaml = YAML.load(File.open(@config_file_path))

      yaml[GLOBAL_OVERRIDES][pod_name].should.equal pod_path
    end

    it "deletes global configuration" do
      run_command('config', "--global", pod_name, pod_path)
      run_command('config', "--global", "--delete", pod_name)
      yaml = YAML.load(File.open(@config_file_path))

      yaml.should.not.has_key? GLOBAL_OVERRIDES
    end



    it "defaults to local scope" do
      run_command('config', pod_name, pod_path)
      yaml = YAML.load(File.open(@config_file_path))

      yaml[LOCAL_OVERRIDES][project_name][pod_name].should.equal pod_path
    end

    it "raises help! if invalid args are provided" do
      [
        lambda { run_command("config", 'ObjectiveSugar') },
        lambda { run_command("config", "--local", 'ObjectiveSugar') },
        lambda { run_command("config", "--global", 'ObjectiveSugar') },
        lambda { run_command("config", '~/code/OSS/ObjectiveSugar') },
      ].each { |invalid| invalid.should.raise CLAide::Help }
    end

    xit "deletes local configuration by default" do
      run_command('config', "--global", pod_name, pod_path)
      run_command('config', "--local", pod_name, pod_path)
      run_command('config', "--delete", pod_name)
      yaml = YAML.load(File.open(@config_file_path))
      puts yaml
      yaml.should.not.has_key? LOCAL_OVERRIDES
      yaml[GLOBAL_OVERRIDES][pod_name].should.equal pod_path
    end

  end
end

