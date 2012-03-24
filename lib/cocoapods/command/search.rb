module Pod
  class Command
    class Search < Command
      def self.banner
%{Search pods:

    $ pod search [QUERY]

      Searches for pods, ignoring case, whose name matches 'QUERY'. If the
      '--full' option is specified, this will also search in the summary and
      description of the pods.}
      end

      def self.options
        "    --stats     Show additional stats (like GitHub watchers and forks)\n" +
        "    --full      Search by name, summary, and description\n" +
        super
      end

      include DisplayPods

      def initialize(argv)
        @stats = argv.option('--stats')
        @full_text_search = argv.option('--full')
        unless @query = argv.arguments.first
          super
        end
      end

      def run
        sets = Source.search_by_name(@query.strip, @full_text_search)
        display_pod_list(sets, @stats)
      end
    end
  end
end
