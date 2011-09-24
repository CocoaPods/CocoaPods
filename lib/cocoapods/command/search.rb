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

      def run
        Source.search_by_name(@query.strip, @full_text_search).each do |set|
          puts "==> #{set.name} (#{set.versions.reverse.join(", ")})"
          puts "    #{set.specification.summary.strip}"
          puts
        end
      end
    end
  end
end
