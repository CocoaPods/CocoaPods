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
        "    --full      Search by name, summary, and description\n" +
        super
      end

      def initialize(argv)
        @full_text_search = argv.option('--full')
        unless @query = argv.arguments.first
          super
        end
      end

      def wrap_text(txt, col = 80)
        txt.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/,"\\1\\3\n    ")
      end

      def run
        Source.search_by_name(@query.strip, @full_text_search).each do |set|
          puts "\e[32m--> #{set.name} (#{set.versions.reverse.join(", ")})\e[0m"
          puts "    #{wrap_text(set.specification.summary).strip}"
          puts "    - Homepage: #{set.specification.homepage}"

          source = set.specification.source
          if source
            url = source[:git] || source[:hg] || source[:svn] || source[:local]
            puts "    - Source:   #{url}" if url
            if  url =~ /github.com/
              original_url, username, reponame = *(url.match(/[:\/](\w+)\/(\w+).git/).to_a)
              if original_url
                repo_info = `curl -s -m 2 http://github.com/api/v2/json/repos/show/#{username}/#{reponame}`
                watchers = repo_info.match(/\"watchers\"\W*:\W*([0-9]+)/).to_a[1]
                forks = repo_info.match(/\"forks\"\W*:\W*([0-9]+)/).to_a[1]
                puts "    - Watchers: " + watchers if watchers
                puts "    - Forks:    " + forks if forks
              end
            end
          end
          puts
        end
      end
    end
  end
end
