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
        ENV['CP_HOME_DIR'] = '~/custom_home_dir'
        @config.home_dir.should == Pathname.new('~/custom_home_dir').expand_path
        ENV.delete('CP_HOME_DIR')
      end

      it 'allows to specify the repos dir with an environment variable' do
        ENV['CP_REPOS_DIR'] = '~/custom_repos_dir'
        @config.repos_dir.should == Pathname.new('~/custom_repos_dir').expand_path
        ENV.delete('CP_REPOS_DIR')
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

      #-----------------------------------------------------------------------#
    end
  end
end
