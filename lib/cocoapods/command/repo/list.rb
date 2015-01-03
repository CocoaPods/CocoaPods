module Pod
  class Command
    class Repo < Command
      class List < Repo
        self.summary = 'List repos'

        self.description = <<-DESC
            List the repos from the local spec-repos directory at `~/.cocoapods/repos/.`
        DESC

        def self.options
          [['--count-only', 'Show the total number of repos']].concat(super)
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
                UI.puts '- Type: git (no remote information available)'
              end
            else
              UI.puts '- Type: local copy'
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
    end
  end
end
