module Pod
  class Command
    class Search < Command
      def self.banner
        %{Search pods:

    $ pod search [QUERY]

      Searches for pods, ignoring case, whose name matches `QUERY'. If the
      `--full' option is specified, this will also search in the summary and
      description of the pods.}
      end

      def self.options
        "    --stats     Show additional stats (like GitHub watchers and forks)\n" +
        "    --full      Search by name, summary, and description\n" +
        super
      end

      def initialize(argv)
        @stats = argv.option('--stats')
        @full_text_search = argv.option('--full')
        unless @query = argv.arguments.first
          super
        end
      end

      def run
        Source.search_by_name(@query.strip, @full_text_search).each do |set|
          puts "\e[32m--> #{set.name} (#{set.versions.reverse.join(", ")})\e[0m"

          puts_wrapped_text(set.specification.summary)
          puts_detail('Homepage', set.specification.homepage)
          source = set.specification.source ? set.specification.source.values[0] : nil
          puts_detail('Source', source)
          puts_github_info(source) if @stats

          puts
        end
      end

      # adapted from http://blog.macromates.com/2006/wrapping-text-with-regular-expressions/
      def puts_wrapped_text(txt, col = 80, indentation = 4)
        indent = ' ' * indentation
        puts txt.strip.gsub(/(.{1,#{col}})( +|$)\n?|(.{#{col}})/, indent + "\\1\\3\n")
      end

      def puts_detail(title,string)
        return if !string
        # 8 is the length of homepage which might be displayed alone
        number_of_spaces = ((8 - title.length) > 0) ? (8 - title.length) : 0
        spaces = ' ' * number_of_spaces
        puts "    - #{title}: #{spaces + string}"
      end

      def puts_github_info(url)
        original_url, username, reponame = *(url.match(/[:\/]([\w\-]+)\/([\w\-]+)\.git/).to_a)

        if original_url
          repo_info = `curl -s -m 2 http://github.com/api/v2/json/repos/show/#{username}/#{reponame}`
          watchers = repo_info.match(/\"watchers\"\W*:\W*([0-9]+)/).to_a[1]
          forks = repo_info.match(/\"forks\"\W*:\W*([0-9]+)/).to_a[1]
          puts_detail('Watchers', watchers)
          puts_detail('Forks', forks)
        end
      end
    end
  end
end
