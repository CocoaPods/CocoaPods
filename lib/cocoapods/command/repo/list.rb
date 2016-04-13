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
        #          - type: git (master)
        #          - URL:  https://github.com/CocoaPods/Specs.git
        #          - path: /Users/lascorbe/.cocoapods/repos/master
        #
        #          test
        #          - type: local copy
        #          - URL: file:///Users/lascorbe/.cocoapods/repos/test
        #          - path: /Users/lascorbe/.cocoapods/repos/test
        #
        def run
          sources = config.sources_manager.all
          print_sources(sources) unless @count_only
          print_count_of_sources(sources)
        end

        private

        # Pretty-prints the source at the given path.
        #
        # @param  [Source] source
        #         The source repository to be printed.
        #
        # @return [void]
        #
        def print_source(source)
          if source.git?
            Dir.chdir(source.repo) do
              branch_name = `git name-rev --name-only HEAD 2>/dev/null`.strip
              branch_name = 'unknown' if branch_name.empty?
              UI.puts "- Type: git (#{branch_name})"
            end
          else
            UI.puts '- Type: local'
          end

          UI.puts "- URL:  #{source.url}"
          UI.puts "- Path: #{source.repo}"
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
              print_source(source)
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
