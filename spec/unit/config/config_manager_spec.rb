require File.expand_path('../../../spec_helper', __FILE__)
require 'yaml'

module Pod

  describe Config::ConfigManager do

    describe "global" do

      @config_file_path = temporary_directory + 'config.yaml'

      before do
        @sut = Config::ConfigManager.new
        @sut.stubs(:home_dir).returns(temporary_directory)
      end

      it "creates a global config file if one didn't exist" do
        FileUtils.rm_rf(@config_file_path)
        @sut.set_global('verbose', 'true')
        @config_file_path.should.exist
      end

      it "stores a global setting" do
        @sut.set_global('verbose', 'true')
        yaml = YAML.load_file(@config_file_path)
        yaml['verbose'].should == true
      end

      it "preserves the existing settings of the configuration file" do
        @sut.set_global('user_name', 'Super Marin')
        @sut.set_global('verbose', 'true')
        yaml = YAML.load_file(@config_file_path)
        yaml['user_name'].should == 'Super Marin'
      end

      xit "allows to store a development pod" do
        @sut.set_global('development.ObjectiveSugar', '~/code/OS')
        yaml = YAML.load_file(@config_file_path)
        yaml['development.ObjectiveSugar'].should == '~/code/OS'
      end

      it "returns a globally decided setting" do
        @sut.set_global('user_name', 'Super Marin')
        @sut.get_setting('user_name').should == 'Super Marin'
      end

      it "verbose by default is false" do
        @sut.should.not.be.verbose
      end

      it "silent by default is false" do
        @sut.should.not.be.silent
      end

      it "skips repo update by default is false" do
        @sut.should.not.skip_repo_update
      end

      it "clean by default is true" do
        @sut.should.be.clean
      end

      it "integrate_targets by default is true" do
        @sut.should.integrate_targets
      end

      it "new_version_message by default is true" do
        @sut.should.new_version_message
      end

      it "cache_root returns the cache root by default" do
        @sut.cache_root.to_s.should.include('Library/Caches/CocoaPods')
      end

      it "max_cache_size is 500 MB by default" do
        @sut.max_cache_size.should == 500
      end
      
      it "aggressive_cache is false by default" do
        @sut.should.not.aggressive_cache
      end

      it "raises if there is an attempt to access an unrecognized attribute" do
        should.raise Config::ConfigManager::NoKeyError do
          @sut.get_setting('idafjaeilfjoasijfopasdj')
        end
      end

      it "can accept aggressive cache from ENV" do
        ENV.stubs(:[]).returns('TRUE')
        @sut.get_setting('aggressive_cache').should == true
      end

      xit "it converts string boolean values"
      xit "it support keypath"
      # key.keypath = 'my value'
    end

    xit "writes local repos for each project" do
      @sut.set_local('verbose', 'true')
      yaml['verbose'].should == true
    end

  end

end
