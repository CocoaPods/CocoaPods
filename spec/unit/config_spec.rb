require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Config do
    before do
      @config = Config.new(false)
    end

    #-------------------------------------------------------------------------#

    describe 'In general' do
      it 'returns the singleton config instance' do
        @config.should.be.instance_of Config
      end

      it 'returns the path to the home dir' do
        @config.home_dir.should == Pathname.new('~/.cocoapods').expand_path
      end

      it 'returns the path to the spec-repos dir' do
        @config.repos_dir.should == Pathname.new('~/.cocoapods/repos').expand_path
      end

      it 'returns the path to the templates dir' do
        @config.templates_dir.should == Pathname.new('~/.cocoapods/templates').expand_path
      end

      it 'returns the path of the default podfiles' do
        @config.default_podfile_path.should == Pathname.new('~/.cocoapods/templates/Podfile.default').expand_path
        @config.default_test_podfile_path.should == Pathname.new('~/.cocoapods/templates/Podfile.test').expand_path
      end

      it 'allows to specify the home dir with an environment variable' do
        ENV['CP_HOME_DIR'] = (SpecHelper.temporary_directory + 'custom_home_dir').to_s
        @config = Config.new(false)
        @config.home_dir.should == (SpecHelper.temporary_directory + 'custom_home_dir').expand_path
        @config.repos_dir.should == (SpecHelper.temporary_directory + 'custom_home_dir/repos').expand_path
        @config.templates_dir.should == (SpecHelper.temporary_directory + 'custom_home_dir/templates').expand_path
        @config.cache_root.should == (SpecHelper.temporary_directory + 'custom_home_dir/cache').expand_path
        ENV.delete('CP_HOME_DIR')
      end

      it 'allows to specify the repos dir with an environment variable' do
        ENV['CP_REPOS_DIR'] = '~/custom_repos_dir'
        @config.repos_dir.should == Pathname.new('~/custom_repos_dir').expand_path
        ENV.delete('CP_REPOS_DIR')
      end

      it 'allows to specify the repos dir with an environment variable that overrides home dir variable' do
        ENV['CP_HOME_DIR'] = '~/custom_home_dir'
        ENV['CP_REPOS_DIR'] = '~/custom_repos_dir'
        @config.repos_dir.should == Pathname.new('~/custom_repos_dir').expand_path
        ENV.delete('CP_REPOS_DIR')
        ENV.delete('CP_HOME_DIR')
      end

      it 'allows to specify the cache dir with an environment variable' do
        ENV['CP_CACHE_DIR'] = (SpecHelper.temporary_directory + 'custom_cache_dir').to_s
        @config = Config.new(false)
        @config.cache_root.should == (SpecHelper.temporary_directory + 'custom_cache_dir').expand_path
        ENV.delete('CP_CACHE_DIR')
      end

      it 'allows to specify the cache dir with a config file' do
        ENV['CP_HOME_DIR'] = SpecHelper.temporary_directory.to_s
        config = { 'cache_root' => 'config_cache_dir' }
        File.write(SpecHelper.temporary_directory + 'config.yaml', config.to_yaml)
        @config = Config.new
        @config.cache_root.should == Pathname.new('config_cache_dir').expand_path
        File.delete(SpecHelper.temporary_directory + 'config.yaml')
        ENV.delete('CP_HOME_DIR')
      end

      it 'allows cache dir environment variable to override the config file' do
        ENV['CP_HOME_DIR'] = SpecHelper.temporary_directory.to_s
        config = { 'cache_root' => 'config_cache_dir' }
        File.write(SpecHelper.temporary_directory + 'config.yaml', config.to_yaml)
        ENV['CP_CACHE_DIR'] = (SpecHelper.temporary_directory + 'custom_cache_dir').to_s
        @config = Config.new
        @config.cache_root.should == (SpecHelper.temporary_directory + 'custom_cache_dir').expand_path
        File.delete(SpecHelper.temporary_directory + 'config.yaml')
        ENV.delete('CP_CACHE_DIR')
        ENV.delete('CP_HOME_DIR')
      end
    end

    #-------------------------------------------------------------------------#

    describe '#with_changes' do
      it 'doesnt raise when using an unknown key' do
        should.not.raise { @config.with_changes(:foo_bar => false) }
      end

      it 'uses the new value inside the block' do
        @config.verbose = true
        called = false
        @config.with_changes(:verbose => false) do
          @config.should.not.be.verbose
          called = true
        end
        called.should.be.true
      end

      it 'reverts to the previous value after the block' do
        @config.verbose = true
        @config.with_changes(:verbose => false)
        @config.should.be.verbose
      end

      it 'reverts to the previous value even when an exception is raised' do
        @config.verbose = true
        should.raise do
          @config.with_changes(:verbose => false) do
            raise 'foo'
          end
        end
        @config.should.be.verbose
      end

      it 'returns the return value of the block' do
        @config.with_changes({}) do
          'foo'
        end.should == 'foo'

        @config.with_changes({}).should.be.nil
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Paths' do
      it 'returns the working directory as the installation root if a Podfile can be found' do
        Dir.chdir(temporary_directory) do
          File.open('Podfile', 'w') {}
          @config.installation_root.should == temporary_directory
        end
      end

      it 'should not return the working directory as the installation root if found Podfile is a directory' do
        Dir.chdir(temporary_directory) do
          path = temporary_directory + 'Podfile'
          path.mkpath
          Dir.chdir(path) do
            @config.installation_root.should == path
          end
        end
      end

      it 'returns the parent directory which contains the Podfile if it can be found' do
        Dir.chdir(temporary_directory) do
          File.open('Podfile', 'w') {}
          sub_dir = temporary_directory + 'sub_dir'
          sub_dir.mkpath
          Dir.chdir(sub_dir) do
            @config.installation_root.should == temporary_directory
          end
        end
      end

      it 'it returns the working directory as the installation root if no Podfile can be found' do
        Dir.chdir(temporary_directory) do
          @config.installation_root.should == temporary_directory
        end
      end

      it 'returns the working directory correctly when it includes unicode characters' do
        unicode_directory = temporary_directory + "ü"
        FileUtils.mkdir(unicode_directory)
        Dir.chdir(unicode_directory) do
          File.open('Podfile', 'w') {}
          @config.installation_root.to_s.should == unicode_directory.to_s
        end
      end

      before do
        @config.installation_root = temporary_directory
      end

      it 'returns the path to the project root' do
        @config.installation_root.should == temporary_directory
      end

      it 'returns the path to the project Podfile if it exists' do
        (temporary_directory + 'Podfile').open('w') { |f| f << '# Yo' }
        @config.podfile_path.should == temporary_directory + 'Podfile'
      end

      it 'can detect yaml Podfiles' do
        (temporary_directory + 'CocoaPods.podfile.yaml').open('w') { |f| f << '# Yo' }
        @config.podfile_path.should == temporary_directory + 'CocoaPods.podfile.yaml'
      end

      it 'can detect files named `CocoaPods.podfile`' do
        (temporary_directory + 'CocoaPods.podfile').open('w') { |f| f << '# Yo' }
        @config.podfile_path.should == temporary_directory + 'CocoaPods.podfile'
      end

      it 'can detect files named `Podfile.rb`' do
        (temporary_directory + 'Podfile.rb').open('w') { |f| f << '# Yo' }
        @config.podfile_path.should == temporary_directory + 'Podfile.rb'
      end

      it 'returns the path to the Pods directory that holds the dependencies' do
        @config.sandbox_root.should == temporary_directory + 'Pods'
      end

      it 'returns the Podfile path' do
        Dir.chdir(temporary_directory) do
          File.open('Podfile', 'w') {}
          @config.podfile_path.should == temporary_directory + 'Podfile'
        end
      end

      it 'returns nils if the Podfile if no paths exists' do
        Dir.chdir(temporary_directory) do
          @config.podfile_path.should.nil?
        end
      end

      it 'returns the Lockfile path' do
        Dir.chdir(temporary_directory) do
          File.open('Podfile', 'w') {}
          File.open('Podfile.lock', 'w') {}
          @config.lockfile_path.should == temporary_directory + 'Podfile.lock'
        end
      end

      it 'returns the search index file' do
        @config.search_index_file.to_s.should.end_with?('search_index.json')
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Default settings' do
      it 'prints out normal information' do
        @config.should.not.be.silent
      end

      it 'does not print verbose information' do
        @config.should.not.be.verbose
      end

      it 'returns the cache root' do
        @config.cache_root.should == Pathname.new(File.join(ENV['HOME'], 'Library/Caches/CocoaPods'))
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Private helpers' do
      it 'returns the path of the user settings file' do
        @config.send(:user_settings_file).should == Pathname.new('~/.cocoapods/config.yaml').expand_path
      end

      it 'can be configured with a hash' do
        hash = { :verbose => true }
        @config.send(:configure_with, hash)
        @config.should.be.verbose
      end

      #----------------------------------------#

      describe '#podfile_path_in_dir' do
        it 'detects the CocoaPods.podfile.yaml file' do
          expected = temporary_directory + 'CocoaPods.podfile.yaml'
          File.open(expected, 'w') {}
          path = @config.send(:podfile_path_in_dir, temporary_directory)
          path.should == expected
        end

        it 'detects the CocoaPods.podfile file' do
          expected = temporary_directory + 'CocoaPods.podfile'
          File.open(expected, 'w') {}
          path = @config.send(:podfile_path_in_dir, temporary_directory)
          path.should == expected
        end

        it 'detects the Podfile file' do
          expected = temporary_directory + 'Podfile'
          File.open(expected, 'w') {}
          path = @config.send(:podfile_path_in_dir, temporary_directory)
          path.should == expected
        end

        it 'returns nils if the Podfile is not available' do
          path = @config.send(:podfile_path_in_dir, temporary_directory)
          path.should.nil?
        end
      end

      describe '#exclude_from_backup' do
        # Conditionally skip the test if `tmutil` is not available.
        has_tmutil = system('tmutil', 'version', :out => File::NULL)
        cit = has_tmutil ? method(:it) : method(:xit)
        cit.call 'excludes the dir from Time Machine backups' do
          dir = temporary_directory + 'no_backup'
          FileUtils.mkdir(dir)
          @config.send(:exclude_from_backup, dir)
          `tmutil isexcluded #{dir}`.chomp.should.start_with?('[Excluded]')
        end

        it 'does not raise if the dir does not exist' do
          dir = temporary_directory + 'no_backup'
          FileUtils.remove_dir(dir, true)
          should.not.raise do
            @config.send(:exclude_from_backup, dir)
          end
        end
      end

      #-----------------------------------------------------------------------#
    end
  end
end
