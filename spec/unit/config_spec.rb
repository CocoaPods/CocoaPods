require File.expand_path('../../spec_helper', __FILE__)

module Pod

  describe Config do
    before do
      Config.instance = nil
    end

    #-------------------------------------------------------------------------#

    describe "In general" do

      it "returns the singleton config instance" do
        config.should.be.instance_of Config
      end

      it "returns the path to the spec-repos dir" do
        config.repos_dir.should == Pathname.new("~/.cocoapods").expand_path
      end

      it "returns the path to the spec-repos dir" do
        config.repos_dir.should == Pathname.new("~/.cocoapods").expand_path
      end

      it "allows to specify whether the aggressive cache should be used with an environment variable" do
        config.aggressive_cache = false
        ENV['CP_AGGRESSIVE_CACHE'] = 'TRUE'
        config.aggressive_cache?.should.be.true
        ENV.delete('CP_AGGRESSIVE_CACHE')
      end

      it "allows to specify the repos dir with an environment variable" do
        ENV['CP_REPOS_DIR'] = '~/custom_repos_dir'
        config.repos_dir.should == Pathname.new("~/custom_repos_dir").expand_path
        ENV.delete('CP_REPOS_DIR')
      end
    end

    #-------------------------------------------------------------------------#

    describe "Paths" do

      it "returns the working directory as the installation root if a Podfile can be found" do
        Dir.chdir(temporary_directory) do
          File.open("Podfile", "w") {}
          config.installation_root.should == temporary_directory
        end
      end

      it "returns the parent directory which contains the Podfile if it can be found" do
        Dir.chdir(temporary_directory) do
          File.open("Podfile", "w") {}
          sub_dir = temporary_directory + 'sub_dir'
          sub_dir.mkpath
          Dir.chdir(sub_dir) do
            config.installation_root.should == temporary_directory
          end
        end
      end

      it "it returns the working directory as the installation root if no Podfile can be found" do
        Dir.chdir(temporary_directory) do
          config.installation_root.should == temporary_directory
        end
      end

      before do
        config.installation_root = temporary_directory
      end

      it "returns the path to the project root" do
        config.installation_root.should == temporary_directory
      end

      it "returns the path to the project Podfile if it exists" do
        (temporary_directory + 'Podfile').open('w') { |f| f << '# Yo' }
        config.podfile_path.should == temporary_directory + 'Podfile'
      end

      it "can detect yaml Podfiles" do
        (temporary_directory + 'CocoaPods.podfile.yaml').open('w') { |f| f << '# Yo' }
        config.podfile_path.should == temporary_directory + 'CocoaPods.podfile.yaml'
      end

      it "can detect files named `CocoaPods.podfile`" do
        (temporary_directory + 'CocoaPods.podfile').open('w') { |f| f << '# Yo' }
        config.podfile_path.should == temporary_directory + 'CocoaPods.podfile'
      end

      it "returns the path to the Pods directory that holds the dependencies" do
        config.sandbox_root.should == temporary_directory + 'Pods'
      end

      it "returns the Podfile path" do
        Dir.chdir(temporary_directory) do
          File.open("Podfile", "w") {}
          config.podfile_path.should == temporary_directory + "Podfile"
        end
      end

      it "returns nils if the Podfile if no paths exists" do
        Dir.chdir(temporary_directory) do
          config.podfile_path.should == nil
        end
      end

      it "returns the Lockfile path" do
        Dir.chdir(temporary_directory) do
          File.open("Podfile", "w") {}
          File.open("Podfile.lock", "w") {}
          config.lockfile_path.should == temporary_directory + "Podfile.lock"
        end
      end

      it "returns the statistics cache file" do
        config.statistics_cache_file.to_s.should.end_with?('statistics.yml')
      end

      it "returns the search index file" do
        config.search_index_file.to_s.should.end_with?('search_index.yaml')
      end

    end

    #-------------------------------------------------------------------------#

    describe "Default settings" do

      before do
        Config.any_instance.stubs(:user_settings_file).returns(Pathname.new('not_found'))
      end

      it "prints out normal information" do
        config.should.not.be.silent
      end

      it "does not print verbose information" do
        config.should.not.be.verbose
      end

      it "cleans SCM dirs in dependency checkouts" do
        config.should.clean
      end

      it "has a default cache size of 500" do
        config.max_cache_size.should == 500
      end

      it "returns the cache root" do
        config.cache_root.should == Pathname.new(File.join(ENV['HOME'], 'Library/Caches/CocoaPods'))
      end

      it "doesn't use aggressive cache" do
        config.should.not.aggressive_cache?
      end

    end

    #-------------------------------------------------------------------------#

    describe "Dependency Injection" do

      it "returns the downloader" do
        downloader = config.downloader(Pathname.new(''), { :git => 'example.com' })
        downloader.target_path.should == Pathname.new('')
        downloader.url.should == 'example.com'
        downloader.cache_root.should == config.cache_root
        downloader.max_cache_size.should == 500
        downloader.aggressive_cache.should.be.false
      end

      it "returns the specification statistics provider" do
        stats_provider = config.spec_statistics_provider
        stats_provider.cache_file.should == config.cache_root + 'statistics.yml'
      end

    end

    #-------------------------------------------------------------------------#

    describe "Private helpers" do

      it "returns the path of the user settings file" do
        config.send(:user_settings_file).should == Pathname.new("~/.cocoapods/config.yaml").expand_path
      end

      it "can be configured with a hash" do
        hash = { :verbose => true }
        config.send(:configure_with, hash)
        config.should.be.verbose
      end

      #----------------------------------------#

      describe "#podfile_path_in_dir" do

        it "detects the CocoaPods.podfile.yaml file" do
          expected = temporary_directory + "CocoaPods.podfile.yaml"
          File.open(expected, "w") {}
          path = config.send(:podfile_path_in_dir, temporary_directory)
          path.should == expected
        end

        it "detects the CocoaPods.podfile file" do
          expected = temporary_directory + "CocoaPods.podfile"
          File.open(expected, "w") {}
          path = config.send(:podfile_path_in_dir, temporary_directory)
          path.should == expected
        end

        it "detects the Podfile file" do
          expected = temporary_directory + "Podfile"
          File.open(expected, "w") {}
          path = config.send(:podfile_path_in_dir, temporary_directory)
          path.should == expected
        end

        it "returns nils if the Podfile is not available" do
          path = config.send(:podfile_path_in_dir, temporary_directory)
          path.should == nil
        end

      end

      #-----------------------------------------------------------------------#

    end
  end
end
