require File.expand_path('../../../spec_helper', __FILE__)
require 'yaml'

module Pod

  describe Config::ConfigManager do

    # manager = Config::ConfigManager.new

    # manager.set_local(keypath, value)
    # manager.unset_local(keypath)

    # manager.set_global(keypath, value)
    # manager.unset_global(keypath)

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
        @sut.get_setting('verbose').should == false
      end

      it "silent by default is false" do
        @sut.get_setting('silent').should == false
      end

      it "skips repo update by default is false" do
        @sut.get_setting('skip_repo_update').should == false
      end

      it "clean by default is true" do
        @sut.get_setting('clean').should == true
      end

      it "integrate_targets by default is true" do
        @sut.get_setting('integrate_targets').should == true
      end

      it "new_version_message by default is true" do
        @sut.get_setting('new_version_message').should == true
      end

      it "cache_root returns the cache root by default" do
        @sut.get_setting('cache_root').to_s.should.include('Library/Caches/CocoaPods')
      end

      it "max_cache_size is 500 MB by default" do
        @sut.get_setting('max_cache_size').should == 500
      end
      
      it "aggressive_cache is false by default" do
        @sut.get_setting('aggressive_cache').should == false
      end

      it "raises if there is an attempt to access an unrecognized attribute" do
        should.raise Config::ConfigManager::NoKeyError do
          @sut.get_setting('idafjaeilfjoasijfopasdj')
        end
      end

      xit "it converts string boolean values"
      xit "it support keypath"
      # key.keypath = 'my value'
    end

    xit "writes local repos for each project" do
      @sut.set_local('verbose', 'true')
      yaml['verbose'].should == true
    end

    xit "works with ENV" do

    end

    xit "writes global repos without specifying project" do
      run_command('config', "--global", pod_name, pod_path)
      yaml = YAML.load(File.open(@config_file_path))

      yaml[GLOBAL_OVERRIDES][pod_name].should.equal pod_path
    end

    xit "deletes global configuration" do
      run_command('config', "--global", pod_name, pod_path)
      run_command('config', "--global", "--delete", pod_name)
      yaml = YAML.load(File.open(@config_file_path))

      yaml.should.not.has_key? GLOBAL_OVERRIDES
    end



  end

end
