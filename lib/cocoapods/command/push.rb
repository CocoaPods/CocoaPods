require 'fileutils'
require 'active_support/core_ext/string/inflections'

module Pod
  class Command
    class Push < Command
      def self.banner
%{Pushing new specifications to a spec-repo:

    $ pod push REPO [NAME.podspec]

      Validates NAME.podspec or `*.podspec' in the current working dir, creates
      a directory and version folder for the pod in the local copy of 
      REPO (~/.cocoapods/[REPO]), copies the podspec file into the version directory,
      and finally it pushes REPO to its remote.}
      end

      def self.options
        [ ["--allow-warnings", "Allows to push if warnings are not evitable"],
          ["--local-only", "Does not perform the step of pushing REPO to its remote"] ].concat(super)
      end

      extend Executable
      executable :git

      def initialize(argv)
        @allow_warnings = argv.option('--allow-warnings')
        @local_only = argv.option('--local-only')
        @repo = argv.shift_argument
        @podspec = argv.shift_argument
        super unless argv.empty? && @repo
      end

      def run
        validate_podspec_files
        check_repo_status
        update_repo
        add_specs_to_repo
        push_repo unless @local_only
      end

      private

      def update_repo
        UI.puts "Updating the `#{@repo}' repo\n".yellow unless config.silent
        # show the output of git even if not verbose
        # TODO: use the `git!' and find a way to show the output in realtime.
        Dir.chdir(repo_dir) { UI.puts `git pull 2>&1` }
      end

      def push_repo
        UI.puts "\nPushing the `#{@repo}' repo\n".yellow unless config.silent
        Dir.chdir(repo_dir) { UI.puts `git push 2>&1` }
      end

      def repo_dir
        dir = config.repos_dir + @repo
        raise Informative, "[!] `#{@repo}' repo not found".red unless dir.exist?
        dir
      end

      def check_repo_status
        # TODO: add specs for staged and unstaged files (tested manually)
        clean = Dir.chdir(repo_dir) { `git status --porcelain  2>&1` } == ''
        raise Informative, "[!] `#{@repo}' repo not clean".red unless clean
      end

      def podspec_files
        files = Pathname.glob(@podspec || "*.podspec")
        raise Informative, "[!] Couldn't find any .podspec file in current directory".red if files.empty?
        files
      end

      # @return [Integer] The number of the podspec files to push.
      #
      def count
        podspec_files.count
      end

      def validate_podspec_files
        UI.puts "\nValidating #{'spec'.pluralize(count)}".yellow unless config.silent
        lint_argv = ["lint"]
        lint_argv << "--only-errors" if @allow_warnings
        lint_argv << "--silent" if config.silent
        all_valid = true
        podspec_files.each do |podspec|
          Spec.new(ARGV.new(lint_argv + [podspec.to_s])).run
        end
      end

      def add_specs_to_repo
        UI.puts "\nAdding the #{'spec'.pluralize(count)} to the `#{@repo}' repo\n".yellow unless config.silent
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
          UI.puts " - #{message}" unless config.silent

          FileUtils.mkdir_p(output_path)
          FileUtils.cp(Pathname.new(spec.name+'.podspec'), output_path)
          Dir.chdir(repo_dir) do
            git!("add #{spec.name}")
            # Bypass the pre-commit hook because we already performed validation
            git!("commit --no-verify -m '#{message}'")
          end
        end
      end
    end
  end
end
