require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe 'Command::List' do
    extend SpecHelper::TemporaryRepos

    before do
      set_up_test_repo
      config.repos_dir = SpecHelper.tmp_repos_path
    end

    it 'presents the known pods' do
      out = run_command('list')
      [/BananaLib/,
       /JSONKit/,
       /\d+ pods were found/,
      ].each { |regex| out.should =~ regex }
    end

    it 'presents the known pods with versions' do
      sets = config.sources_manager.aggregate.all_sets
      jsonkit_set = sets.find { |s| s.name == 'JSONKit' }

      out = run_command('list')
      [/BananaLib 1.0/,
       /JSONKit #{jsonkit_set.versions.first}/,
       /\d+ pods were found/,
      ].each { |regex| out.should =~ regex }
    end

    describe '--installed' do
      extend SpecHelper::Command

      it 'lists installed pods with their versions' do
        Dir.chdir(SpecHelper.temporary_directory) do
          File.open('Podfile', 'w') do |f|
            f.write("platform :ios, '9.0'\ntarget 'TestApp' do\npod 'JSONKit'\nend")
          end

          lockfile_content = <<-LOCKFILE.strip_heredoc
            PODS:
              - BananaLib (1.0)
              - JSONKit (1.4)

            DEPENDENCIES:
              - BananaLib
              - JSONKit

            SPEC REPOS:
              trunk:
                - BananaLib
                - JSONKit

            SPEC CHECKSUMS:
              BananaLib: abc123
              JSONKit: def456

            PODFILE CHECKSUM: xyz789

            COCOAPODS: 1.11.0
          LOCKFILE

          File.open('Podfile.lock', 'w') { |f| f.write(lockfile_content) }

          out = run_command('list', '--installed')
          out.should.include('BananaLib 1.0')
          out.should.include('JSONKit 1.4')
          out.should.include('2 pods installed')
        end
      end

      it 'reports when no pods are installed' do
        Dir.chdir(SpecHelper.temporary_directory) do
          File.open('Podfile', 'w') do |f|
            f.write("platform :ios, '9.0'\ntarget 'TestApp' do\nend")
          end

          lockfile_content = <<-LOCKFILE.strip_heredoc
            PODS:

            DEPENDENCIES:

            SPEC REPOS:

            SPEC CHECKSUMS:

            PODFILE CHECKSUM: xyz789

            COCOAPODS: 1.11.0
          LOCKFILE

          File.open('Podfile.lock', 'w') { |f| f.write(lockfile_content) }

          out = run_command('list', '--installed')
          out.should.include('No pods are installed')
        end
      end

      it 'raises an error when Podfile is missing' do
        Dir.chdir(SpecHelper.temporary_directory) do
          should.raise Informative do
            run_command('list', '--installed')
          end
        end
      end
    end
  end
end
