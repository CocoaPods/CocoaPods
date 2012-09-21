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
        [[
          "--full",  "Search by name, summary, and description",
          "--stats", "Show additional stats (like GitHub watchers and forks)"
        ]].concat(super)
      end

      def initialize(argv)
        @full_text_search = argv.option('--full')
        @stats = argv.option('--stats')
        @query = argv.shift_argument
        super unless argv.empty? && @query
      end

      def run
        sets = Source.search_by_name(@query.strip, @full_text_search)
        sets.each { |set| UI.pod(set, (@stats ? :stats : :normal)) }
      end
    end
  end
end
