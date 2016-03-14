require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::Update do
    it 'tells the user that no Podfile was found in the project dir' do
      exception = lambda { run_command('update', '--no-repo-update') }.should.raise Informative
      exception.message.should.include "No `Podfile' found in the project directory."
    end

    it 'updates the spec repos by default' do
      config.with_changes(:skip_repo_update => nil) do
        Pod::Command.parse(['update'])
        config.skip_repo_update.should.be.false
      end
    end

    it "doesn't update the spec repos if that option was given" do
      config.with_changes(:skip_repo_update => nil) do
        Pod::Command.parse(['update', '--no-repo-update'])
        config.skip_repo_update.should.be.true
      end
    end

    describe 'with Podfile' do
      extend SpecHelper::TemporaryRepos

      before do
        file = temporary_directory + 'Podfile'
        File.open(file, 'w') do |f|
          f.puts('platform :ios')
          f.puts('pod "BananaLib", "1.0"')
        end
      end

      it 'tells the user that no Lockfile was found in the project dir' do
        exception = lambda { run_command('update', 'BananaLib', '--no-repo-update') }.should.raise Informative
        exception.message.should.include "No `Podfile.lock' found in the project directory"
      end

      describe 'tells the user that the Pods cannot be updated unless they are installed' do
        extend SpecHelper::TemporaryRepos

        before do
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
          should.raise Informative do
            run_command('update', 'Reachability', '--no-repo-update')
          end.message.should.include 'The `Reachability` Pod is not ' \
            'installed and cannot be updated'
        end

        it 'for multiple missing Pods' do
          exception = lambda { run_command('update', 'Reachability', 'BananaLib2', '--no-repo-update') }.should.raise Informative
          exception.message.should.include 'Pods `Reachability`, `BananaLib2` are not installed and cannot be updated'
        end
      end
    end
  end
end
