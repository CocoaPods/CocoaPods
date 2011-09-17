module Pod
  class Command
    class Search < Command
      def initialize(argv)
        unless @query = argv.arguments.first
          super
        end
      end

      def run
        Source.search_by_name(@query.strip).each do |set|
          puts "#{set.name} (#{set.versions.reverse.join(", ")})"
        end
      end
    end
  end
end
