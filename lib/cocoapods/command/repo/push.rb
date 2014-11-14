require 'fileutils'
require 'active_support/core_ext/string/inflections'

module Pod
  class Command
    class Repo < Command
      class Push < Repo
        self.summary = 'Push new specifications to a spec-repo'

        self.description = <<-DESC
        Validates `NAME.podspec` or `*.podspec` in the current working dir,
        creates a directory and version folder for the pod in the local copy of
        `REPO` (~/.cocoapods/repos/[REPO]), copies the podspec file into the
        version directory, and finally it pushes `REPO` to its remote.
        DESC

        self.arguments = [
          CLAide::Argument.new('REPO', true),
          CLAide::Argument.new('NAME.podspec', false),
        ]

        def self.options
          [['--allow-warnings', 'Allows pushing even if there are warnings'],
           ['--local-only', 'Does not perform the step of pushing REPO to its remote']].concat(super)
        end

        def initialize(argv)
          @allow_warnings = argv.flag?('allow-warnings')
          @local_only = argv.flag?('local-only')
          @repo = argv.shift_argument
          @podspec = argv.shift_argument
          super
        end

        def validate!
          super
          help! 'A spec-repo name is required.' unless @repo
        end

        def run
          check_if_master_repo
          validate_podspec_files
          check_repo_status
          update_repo
          add_specs_to_repo
          push_repo unless @local_only
        end

        #---------------------------------------------------------------------#

        private

        # @!group Push sub-steps

        extend Executable
        executable :git

        # Temporary check to ensure that users do not push accidentally private
        # specs to the master repo.
        #
        def check_if_master_repo
          remotes = Dir.chdir(repo_dir) { `git remote -v 2>&1` }
          master_repo_urls = [
            'git@github.com:CocoaPods/Specs.git',
            'https://github.com/CocoaPods/Specs.git',
          ]
          is_master_repo = master_repo_urls.any? do |url|
            remotes.include?(url)
          end

          if is_master_repo
            raise Informative, 'To push to the CocoaPods master repo use ' \
              "the `pod trunk push` command.\n\nIf you are using a fork of " \
              'the master repo for private purposes we recommend to migrate ' \
              'to a clean private repo. To disable this check remove the ' \
              'remote pointing to the CocoaPods master repo.'
          end
        end

        # Performs a full lint against the podspecs.
        #
        def validate_podspec_files
          UI.puts "\nValidating #{'spec'.pluralize(count)}".yellow
          podspec_files.each do |podspec|
            validator = Validator.new(podspec, SourcesManager.all.map(&:url))
            validator.allow_warnings = @allow_warnings
            begin
              validator.validate
            rescue
              raise Informative, "The `#{podspec}` specification does not validate."
            end
            raise Informative, "The `#{podspec}` specification does not validate." unless validator.validated?
          end
        end

        # Checks that the repo is clean.
        #
        # @raise  If the repo is not clean.
        #
        # @todo   Add specs for staged and unstaged files.
        #
        # @todo   Gracefully handle the case where source is not under git
        #         source control.
        #
        # @return [void]
        #
        def check_repo_status
          clean = Dir.chdir(repo_dir) { `git status --porcelain  2>&1` } == ''
          raise Informative, "The repo `#{@repo}` at #{UI.path repo_dir} is not clean" unless clean
        end

        # Updates the git repo against the remote.
        #
        # @return [void]
        #
        def update_repo
          UI.puts "Updating the `#{@repo}' repo\n".yellow
          Dir.chdir(repo_dir) { UI.puts `git pull 2>&1` }
        end

        # Commits the podspecs to the source, which should be a git repo.
        #
        # @note   The pre commit hook of the repo is skipped as the podspecs have
        #         already been linted.
        #
        # @return [void]
        #
        def add_specs_to_repo
          UI.puts "\nAdding the #{'spec'.pluralize(count)} to the `#{@repo}' repo\n".yellow
          podspec_files.each do |spec_file|
            spec = Pod::Specification.from_file(spec_file)
            output_path = File.join(repo_dir, spec.name, spec.version.to_s)
            if Pathname.new(output_path).exist?
              message = "[Fix] #{spec}"
            elsif Pathname.new(File.join(repo_dir, spec.name)).exist?
              message = "[Update] #{spec}"
            else
              message = "[Add] #{spec}"
            end

            FileUtils.mkdir_p(output_path)
            FileUtils.cp(spec_file, output_path)
            Dir.chdir(repo_dir) do
              # only commit if modified
              if git!('status --porcelain 2>&1').include?(spec.name)
                UI.puts " - #{message}"
                git!("add #{spec.name}")
                git!("commit --no-verify -m '#{message}'")
              else
                UI.puts " - [No change] #{spec}"
              end
            end
          end
        end

        # Pushes the git repo against the remote.
        #
        # @return [void]
        #
        def push_repo
          UI.puts "\nPushing the `#{@repo}' repo\n".yellow
          Dir.chdir(repo_dir) { UI.puts `git push origin master 2>&1` }
        end

        #---------------------------------------------------------------------#

        private

        # @!group Private helpers

        # @return [Pathname] The directory of the repository.
        #
        def repo_dir
          specs_dir = Pathname.new(File.join(config.repos_dir, @repo, 'Specs'))
          dir = config.repos_dir + @repo
          if specs_dir.exist?
            dir = specs_dir
          elsif dir.exist?
            dir
          else
            raise Informative, "`#{@repo}` repo not found either in #{specs_dir} or #{dir}"
          end
          dir
        end

        # @return [Array<Pathname>] The path of the specifications to push.
        #
        def podspec_files
          files = Pathname.glob(@podspec || '*.podspec')
          raise Informative, "Couldn't find any .podspec file in current directory" if files.empty?
          files
        end

        # @return [Integer] The number of the podspec files to push.
        #
        def count
          podspec_files.count
        end

        #---------------------------------------------------------------------#
      end
    end
  end
end
