require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::Project do
    it 'tells the user that no Podfile or podspec was found in the current working dir' do
      Command::Install.new(CLAide::ARGV.new(['--no-repo-update']))
      config.skip_repo_update.should.be.true
    end
  end

  #---------------------------------------------------------------------------#

  describe Command::Install do
    it 'tells the user that no Podfile or podspec was found in the project dir' do
      exception = lambda { run_command('install', '--no-repo-update') }.should.raise Informative
      exception.message.should.include "No `Podfile' found in the project directory."
    end
  end

  #---------------------------------------------------------------------------#

  describe Command::Update do
    extend SpecHelper::TemporaryRepos

    it 'tells the user that no Podfile was found in the project dir' do
      exception = lambda { run_command('update', '--no-repo-update') }.should.raise Informative
      exception.message.should.include "No `Podfile' found in the project directory."
    end

    it 'tells the user that no Lockfile was found in the project dir' do
      file = temporary_directory + 'Podfile'
      File.open(file, 'w') do |f|
        f.puts('platform :ios')
        f.puts('pod "Reachability"')
      end
      Dir.chdir(temporary_directory) do
        exception = lambda { run_command('update', 'Reachability', '--no-repo-update') }.should.raise Informative
        exception.message.should.include "No `Podfile.lock' found in the project directory"
      end
    end

    describe 'tells the user that the Pods cannot be updated unless they are installed' do
      extend SpecHelper::TemporaryRepos

      before do
        file = temporary_directory + 'Podfile'
        File.open(file, 'w') do |f|
          f.puts('platform :ios')
          f.puts('pod "BananaLib", "1.0"')
        end

        podfile = Podfile.new do
          platform :ios
          pod 'BananaLib', '1.0'
        end
        specs = [
          Specification.new do |s|
            s.name = 'BananaLib'
            s.version = '1.0'
          end,
        ]
        external_sources = {}
        Lockfile.generate(podfile, specs, external_sources).write_to_disk(temporary_directory + 'Podfile.lock')
      end

      it 'for a single missing Pod' do
        Dir.chdir(temporary_directory) do
          should.raise Informative do
            run_command('update', 'Reachability', '--no-repo-update')
          end.message.should.include 'The `Reachability` Pod is not ' \
          'installed and cannot be updated'
        end
      end

      it 'for multiple missing Pods' do
        Dir.chdir(temporary_directory) do
          exception = lambda { run_command('update', 'Reachability', 'BananaLib2', '--no-repo-update') }.should.raise Informative
          exception.message.should.include 'Pods `Reachability`, `BananaLib2` are not installed and cannot be updated'
        end
      end
    end
  end

  #---------------------------------------------------------------------------#
end
