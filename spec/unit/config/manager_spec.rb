require File.expand_path('../../../spec_helper', __FILE__)
require 'yaml'

module Pod

  describe Config::Manager do

    describe "global" do

      @config_file_path = temporary_directory + 'config.yaml'

      before do
        FileUtils.rm_rf(@config_file_path)
        @subject = Config::Manager.new
      end

      xit "has a singleton" do
        Config::Manager.instance.should === Config::Manager.instance
      end

      xit "creates a global config file if one didn't exist" do
        FileUtils.rm_rf(@config_file_path)
        @subject.set_global('verbose', true)
        @config_file_path.should.exist
      end

      xit "stores a global setting" do
        @subject.set_global('verbose', true)
        yaml = YAML.load_file(@config_file_path)
        yaml['verbose'].should == true
      end

      xit "preserves the existing settings of the configuration file" do
        @subject.set_global('silent', true)
        @subject.set_global('verbose', true)
        yaml = YAML.load_file(@config_file_path)
        yaml['silent'].should == true
      end

      xit "allows to store a development pod" do
        @subject.set_global('development.ObjectiveSugar', '~/code/OS')
        yaml = YAML.load_file(@config_file_path)
        yaml['development.ObjectiveSugar'].should == '~/code/OS'
      end

      xit "returns a globally decided setting" do
        @subject.set_global('silent', true)
        @subject.should.be.silent
      end

      xit "verbose by default is false" do
        @subject.should.not.be.verbose
      end

      xit "silent by default is false" do
        @subject.should.not.be.silent
      end

      xit "is verbose only if silent is false and verbose is true" do
        @subject.set_global('silent', true)
        @subject.set_global('verbose', true)

        @subject.should.not.be.verbose
      end

      xit "skips repo update by default is false" do
        @subject.should.not.skip_repo_update?
      end

      xit "clean by default is true" do
        @subject.should.be.clean
      end

      xit "integrate_targets by default is true" do
        @subject.should.integrate_targets
      end

      xit "new_version_message by default is true" do
        @subject.should.new_version_message
      end

      xit "max_cache_size is 500 MB by default" do
        @subject.max_cache_size.should == 500
      end

      xit "aggressive_cache is false by default" do
        @subject.should.not.aggressive_cache
      end

      xit "raises if there is an attempt to access an unrecognized attribute" do
        should.raise Config::Manager::NoKeyError do
          @subject.get_setting('idafjaeilfjoasijfopasdj')
        end
      end

      xit "can accept aggressive cache from ENV" do
        @subject.set_global('aggressive_cache', false)
        ENV['CP_AGGRESSIVE_CACHE'] = 'TRUE'
        @subject.get_setting('aggressive_cache').should == true
        ENV.delete('CP_AGGRESSIVE_CACHE')
      end

      describe "development repos" do

        xit "has a friendly API for development repos" do
          @subject.set_global('development.ObjectiveSugar', '~/code/OS')
          @subject.devevelopment_pod('ObjectiveSugar').should.equal '~/code/OS'
        end

      end
    end

  end

end

