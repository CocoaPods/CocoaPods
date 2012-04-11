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
        Presenter.options + super
      end

      def initialize(argv)
        @full_text_search = argv.option('--full')
        @presenter = Presenter.new(argv)
        @query = argv.shift_argument
        super unless argv.empty? && @query
      end

      def run
        sets = Source.search_by_name(@query.strip, @full_text_search)
        puts @presenter.render(sets)
      end
    end
  end
end
