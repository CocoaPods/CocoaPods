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
        SetPresent.set_present_options +
        super
      end

      include SetPresent

      def initialize(argv)
        parse_set_options(argv)
        @full_text_search = argv.option('--full')
        unless @query = argv.arguments.first
          super
        end
      end

      def run
        sets = Source.search_by_name(@query.strip, @full_text_search)
        present_sets(sets)
      end
    end
  end
end
