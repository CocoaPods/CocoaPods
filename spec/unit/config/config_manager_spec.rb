require File.expand_path('../../../spec_helper', __FILE__)
require 'yaml'

module Pod

  describe Config::ConfigManager do

    describe "global" do

      @config_file_path = temporary_directory + 'config.yaml'

      before do
        @subject = Config::ConfigManager.instance
        @subject.stubs(:home_dir).returns(temporary_directory)
      end

      it "creates a global config file if one didn't exist" do
        FileUtils.rm_rf(@config_file_path)
        @subject.set_global('verbose', 'true')
        @config_file_path.should.exist
      end

      it "stores a global setting" do
        @subject.set_global('verbose', 'true')
        yaml = YAML.load_file(@config_file_path)
        yaml['verbose'].should == true
      end

      it "preserves the existing settings of the configuration file" do
        @subject.set_global('silent', 'true')
        @subject.set_global('verbose', 'true')
        yaml = YAML.load_file(@config_file_path)
        yaml['silent'].should == true
      end

      xit "allows to store a development pod" do
        @subject.set_global('development.ObjectiveSugar', '~/code/OS')
        yaml = YAML.load_file(@config_file_path)
        yaml['development.ObjectiveSugar'].should == '~/code/OS'
      end

      it "returns a globally decided setting" do
        @subject.set_global('user_name', 'Super Marin')
        @subject.get_setting('user_name').should == 'Super Marin'
      end

      it "verbose by default is false" do
        @subject.should.not.be.verbose
      end

      it "silent by default is false" do
        @subject.should.not.be.silent
      end

      it "skips repo update by default is false" do
        @subject.should.not.skip_repo_update
      end

      it "clean by default is true" do
        @subject.should.be.clean
      end

      it "integrate_targets by default is true" do
        @subject.should.integrate_targets
      end

      it "new_version_message by default is true" do
        @subject.should.new_version_message
      end

      it "cache_root returns the cache root by default" do
        @subject.cache_root.to_s.should.include('Library/Caches/CocoaPods')
      end

      it "max_cache_size is 500 MB by default" do
        @subject.max_cache_size.should == 500
      end
      
      it "aggressive_cache is false by default" do
        @subject.should.not.aggressive_cache
      end

      it "raises if there is an attempt to access an unrecognized attribute" do
        should.raise Config::ConfigManager::NoKeyError do
          @subject.get_setting('idafjaeilfjoasijfopasdj')
        end
      end

      it "can accept aggressive cache from ENV" do
        ENV.stubs(:[]).returns('TRUE')
        @subject.get_setting('aggressive_cache').should == true
      end

    end

    xit "writes local repos for each project" do
      @subject.set_local('verbose', 'true')
      yaml['verbose'].should == true
    end

  end

end
