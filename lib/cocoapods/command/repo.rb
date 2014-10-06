require 'fileutils'
require 'cocoapods/command/repo/push'

module Pod
  class Command
    class Repo < Command
      self.abstract_command = true

      # @todo should not show a usage banner!
      #
      self.summary = 'Manage spec-repositories'
      self.default_subcommand = 'list'

      class Add < Repo
        self.summary = 'Add a spec repo.'

        self.description = <<-DESC
          Clones `URL` in the local spec-repos directory at `~/.cocoapods/repos/`. The
          remote can later be referred to by `NAME`.
        DESC

        self.arguments = [
          CLAide::Argument.new('NAME',   true),
          CLAide::Argument.new('URL',    true),
          CLAide::Argument.new('BRANCH', false),
        ]

        def self.options
          [
            ['--shallow', 'Create a shallow clone (fast clone, but no push capabilities)'],
          ].concat(super)
        end

        def initialize(argv)
          @shallow = argv.flag?('shallow', false)
          @name, @url, @branch = argv.shift_argument, argv.shift_argument, argv.shift_argument
          super
        end

        def validate!
          super
          unless @name && @url
            help! 'Adding a repo needs a `NAME` and a `URL`.'
          end
        end

        def run
          prefix = @shallow ? 'Creating shallow clone of' : 'Cloning'
          UI.section("#{prefix} spec repo `#{@name}` from `#{@url}`#{" (branch `#{@branch}`)" if @branch}") do
            config.repos_dir.mkpath
            Dir.chdir(config.repos_dir) do
              command = "clone '#{@url}' #{@name}"
              command << ' --depth=1' if @shallow
              git!(command)
            end
            Dir.chdir(dir) { git!("checkout #{@branch}") } if @branch
            SourcesManager.check_version_information(dir)
          end
        end
      end

      #-----------------------------------------------------------------------#

      class Update < Repo
        self.summary = 'Update a spec repo.'

        self.description = <<-DESC
          Updates the local clone of the spec-repo `NAME`. If `NAME` is omitted
          this will update all spec-repos in `~/.cocoapods/repos`.
        DESC

        self.arguments = [
          CLAide::Argument.new('NAME', false),
        ]

        def initialize(argv)
          @name = argv.shift_argument
          super
        end

        def run
          SourcesManager.update(@name, true)
        end
      end

      #-----------------------------------------------------------------------#

      class Lint < Repo
        self.summary = 'Validates all specs in a repo.'

        self.description = <<-DESC
          Lints the spec-repo `NAME`. If a directory is provided it is assumed
          to be the root of a repo. Finally, if `NAME` is not provided this
          will lint all the spec-repos known to CocoaPods.
        DESC

        self.arguments = [
          CLAide::Argument.new(%w(NAME DIRECTORY), false),
        ]

        def self.options
          [['--only-errors', 'Lint presents only the errors']].concat(super)
        end

        def initialize(argv)
          @name = argv.shift_argument
          @only_errors = argv.flag?('only-errors')
          super
        end

        # @todo Part of this logic needs to be ported to cocoapods-core so web
        #       services can validate the repo.
        #
        # @todo add UI.print and enable print statements again.
        #
        def run
          if @name
            dirs = File.exist?(@name) ? [Pathname.new(@name)] : [dir]
          else
            dirs = config.repos_dir.children.select(&:directory?)
          end
          dirs.each do |dir|
            SourcesManager.check_version_information(dir)
            UI.puts "\nLinting spec repo `#{dir.realpath.basename}`\n".yellow

            validator = Source::HealthReporter.new(dir)
            validator.pre_check do |_name, _version|
              UI.print '.'
            end
            report = validator.analyze
            UI.puts
            UI.puts

            report.pods_by_warning.each do |message, versions_by_name|
              UI.puts "-> #{message}".yellow
              versions_by_name.each { |name, versions| UI.puts "  - #{name} (#{versions * ', '})" }
              UI.puts
            end

            report.pods_by_error.each do |message, versions_by_name|
              UI.puts "-> #{message}".red
              versions_by_name.each { |name, versions| UI.puts "  - #{name} (#{versions * ', '})" }
              UI.puts
            end

            UI.puts "Analyzed #{report.analyzed_paths.count} podspecs files.\n\n"
            if report.pods_by_error.count.zero?
              UI.puts 'All the specs passed validation.'.green << "\n\n"
            else
              raise Informative, "#{report.pods_by_error.count} podspecs failed validation."
            end
          end
        end
      end

      #-----------------------------------------------------------------------#

      class Remove < Repo
        self.summary = 'Remove a spec repo'

        self.description = <<-DESC
          Deletes the remote named `NAME` from the local spec-repos directory at `~/.cocoapods/repos/.`
        DESC

        self.arguments = [
          CLAide::Argument.new('NAME', true),
        ]

        def initialize(argv)
          @name = argv.shift_argument
          super
        end

        def validate!
          super
          help! 'Deleting a repo needs a `NAME`.' unless @name
          help! "repo #{@name} does not exist" unless File.directory?(dir)
          help! "You do not have permission to delete the #{@name} repository." \
                'Perhaps try prefixing this command with sudo.' unless File.writable?(dir)
        end

        def run
          UI.section("Removing spec repo `#{@name}`") do
            FileUtils.rm_rf(dir)
          end
        end
      end

      #-----------------------------------------------------------------------#

      class List < Repo
        self.summary = 'List repos'

        self.description = <<-DESC
            List the repos from the local spec-repos directory at `~/.cocoapods/repos/.`
        DESC

        def self.options
          [["--count-only", "Show the total number of repos"]].concat(super)
        end

        def initialize(argv)
          @count_only = argv.flag?('count-only')
          super
        end

        # @output  Examples:
        #
        #          master
        #          - type: git (origin)
        #          - URL:  https://github.com/CocoaPods/Specs.git
        #          - path: /Users/lascorbe/.cocoapods/repos/master
        #
        #          test
        #          - type: local copy
        #          - path: /Users/lascorbe/.cocoapods/repos/test
        #
        def run
          sources = SourcesManager.all
          print_sources(sources) unless @count_only
          print_count_of_sources(sources)
        end

        private

        # Pretty-prints the source at the given path.
        #
        # @param  [String,Pathname] path
        #         The path of the source to be printed.
        #
        # @return [void]
        #
        def print_source_at_path(path)
          Dir.chdir(path) do
            if SourcesManager.git_repo?(path)
              remote_name = branch_remote_name(branch_name)
              if remote_name
                UI.puts "- Type: git (#{remote_name})"
                url = url_of_git_repo(remote_name)
                UI.puts "- URL:  #{url}"
              else
                UI.puts "- Type: git (no remote information available)"
              end
            else
              UI.puts "- Type: local copy"
            end
            UI.puts "- Path: #{path}"
          end
        end

        # Pretty-prints the given sources.
        #
        # @param  [Array<Source>] sources
        #         The sources that should be printed.
        #
        # @return [void]
        #
        def print_sources(sources)
          sources.each do |source|
            UI.title source.name do
              print_source_at_path source.repo
            end
          end
          UI.puts "\n"
        end

        # Pretty-prints the number of sources.
        #
        # @param  [Array<Source>] sources
        #         The sources whose count should be printed.
        #
        # @return [void]
        #
        def print_count_of_sources(sources)
          number_of_repos = sources.length
          repo_string = number_of_repos != 1 ? 'repos' : 'repo'
          UI.puts "#{number_of_repos} #{repo_string}".green
        end
      end

      #-----------------------------------------------------------------------#

      extend Executable
      executable :git

      def dir
        config.repos_dir + @name
      end

      # Returns the branch name (i.e. master).
      #
      # @return [String] The name of the current branch.
      #
      def branch_name
        `git name-rev --name-only HEAD`.strip
      end

      # Returns the branch remote name (i.e. origin).
      #
      # @param  [#to_s] branch_name
      #         The branch name to look for the remote name.
      #
      # @return [String] The given branch's remote name.
      #
      def branch_remote_name(branch_name)
        `git config branch.#{branch_name}.remote`.strip
      end

      # Returns the url of the given remote name
      # (i.e. git@github.com:CocoaPods/Specs.git).
      #
      # @param  [#to_s] remote_name
      #         The branch remote name to look for the url.
      #
      # @return [String] The URL of the given remote.
      #
      def url_of_git_repo(remote_name)
        `git config remote.#{remote_name}.url`.strip
      end
    end
  end
end
