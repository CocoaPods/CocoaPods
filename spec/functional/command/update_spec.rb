require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::Update do
    it 'tells the user that no Podfile was found in the project dir' do
      exception = lambda { run_command('update', '--no-repo-update') }.should.raise Informative
      exception.message.should.include "No `Podfile' found in the project directory."
    end

    describe 'with Podfile' do
      extend SpecHelper::TemporaryRepos

      before do
        file = temporary_directory + 'Podfile'
        File.open(file, 'w') do |f|
          f.puts('platform :ios')
          f.puts('pod "BananaLib", "1.0"')
          f.puts('pod "CoconutLib", "1.0"')
          f.puts('pod "OCMock", "3.4"')
        end
      end

      def generate_lockfile
        podfile = Podfile.new do
          platform :ios
          pod 'BananaLib', '1.0'
          pod 'CoconutLib', '1.0'
          pod 'OCMock', '3.4'
        end
        specs = [
          Specification.new do |s|
            s.name = 'BananaLib'
            s.version = '1.0'
          end,
          Specification.new do |s|
            s.name = 'CoconutLib'
            s.version = '2.0'
          end,
          Specification.new do |s|
            s.name = 'OCMock'
            s.version = '3.4'
          end,
        ]
        external_sources = {}
        specs_by_source = {
          Source.new(fixture('spec-repos/master')) => specs,
        }
        Lockfile.generate(podfile, specs, external_sources, specs_by_source).
          write_to_disk(temporary_directory + 'Podfile.lock')
      end

      describe 'updates of the spec repos' do
        before do
          Installer.any_instance.expects(:install!)
        end

        it 'updates the spec repos by default' do
          Installer.any_instance.expects(:repo_update=).with(true)
          run_command('update')
        end

        it "doesn't update the spec repos if that option was given" do
          Installer.any_instance.expects(:repo_update=).with(false)
          run_command('update', '--no-repo-update')
        end
      end

      describe 'installs the updates' do
        before do
          Installer.any_instance.expects(:install!)
        end

        describe 'all pods' do
          it 'updates all pods' do
            Installer.any_instance.expects(:update=).with(true)
            run_command('update')
          end
        end

        describe 'selected pods' do
          before do
            generate_lockfile
          end

          it 'updates selected pods' do
            Installer.any_instance.expects(:update=).with(:pods => ['BananaLib'])
            run_command('update', 'BananaLib')
          end
        end

        describe 'selected repo' do
          before do
            generate_lockfile
            set_up_test_repo
            config.repos_dir = SpecHelper.tmp_repos_path

            spec1 = (fixture('spec-repos') + 'test_repo/JSONKit/1.4/JSONKit.podspec').read
            spec2 = (fixture('spec-repos') + 'test_repo/BananaLib/1.0/BananaLib.podspec').read

            File.open(temporary_directory + 'JSONKit.podspec', 'w') { |f| f.write(spec1) }
            File.open(temporary_directory + 'BananaLib.podspec', 'w') { |f| f.write(spec2) }
          end

          it 'updates pods in repo and in lockfile' do
            Installer.any_instance.expects(:update=).with(:pods => %w(BananaLib CoconutLib OCMock))
            run_command('update', '--sources=master')
          end
        end
      end

      describe 'tells the user that no lockfile was found in the project dir' do
        it 'for --no-repo-update' do
          exception = lambda { run_command('update', 'BananaLib', '--no-repo-update') }.should.raise Informative
          exception.message.should.include "No `Podfile.lock' found in the project directory"
        end

        it 'for --exclude-pods' do
          exception = lambda { run_command('update', '--exclude-pods=BananaLib') }.should.raise Informative
          exception.message.should.include "No `Podfile.lock' found in the project directory"
        end

        it 'for --sources' do
          exception = lambda { run_command('update', '--sources=trunk') }.should.raise Informative
          exception.message.should.include "No `Podfile.lock' found in the project directory"
        end
      end

      describe 'tells the user that the Pods cannot be updated unless they are installed' do
        before do
          generate_lockfile
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

      describe 'ignored pods' do
        before do
          generate_lockfile
        end

        describe 'successfully ignores skipped pods' do
          before do
            Installer.any_instance.expects(:install!)
          end

          it 'ignores skiped pod' do
            Installer.any_instance.expects(:update=).with(:pods => %w(BananaLib CoconutLib))
            run_command('update', '--exclude-pods=OCMock')
          end

          it 'ignores multiple skipped pods' do
            Installer.any_instance.expects(:update=).with(:pods => ['OCMock'])
            run_command('update', '--exclude-pods=BananaLib,CoconutLib')
          end
        end

        describe 'when a single supplied Pod is not installed' do
          it 'raises with single message' do
            should.raise Informative do
              run_command('update', '--exclude-pods=Reachability,BananaLib')
            end.message.should.include 'Trying to skip `Reachability` Pod which is not installed'
          end
        end

        describe 'when multiple supplied Pods are not installed' do
          it 'raises with plural message' do
            should.raise Informative do
              run_command('update', '--exclude-pods=Reachability,Alamofire')
            end.message.should.include 'Trying to skip `Reachability`, `Alamofire` ' \
            'Pods which are not installed'
          end
        end
      end
    end
  end
end
