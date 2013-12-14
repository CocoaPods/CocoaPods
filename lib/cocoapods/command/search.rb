module Pod
  class Command
    class Search < Command
      self.summary = 'Searches for pods'

      self.description = <<-DESC
        Searches for pods, ignoring case, whose name matches `QUERY'. If the
        `--full' option is specified, this will also search in the summary and
        description of the pods.
      DESC

      self.arguments = '[QUERY]'

      def self.options
        [
          ["--full",  "Search by name, summary, and description"],
          ["--stats", "Show additional stats (like GitHub watchers and forks)"],
          ["--ios",   "Restricts the search to Pods supported on iOS"],
          ["--osx",   "Restricts the search to Pods supported on OS X"],
          ["--web",   "Searches on cocoapods.org"]
        ].concat(super.reject { |option, _| option == '--silent' })
      end

      def initialize(argv)
        @full_text_search = argv.flag?('full')
        @stats = argv.flag?('stats')
        @supported_on_ios = argv.flag?('ios')
        @supported_on_osx = argv.flag?('osx')
        @web = argv.flag?('web')
        @query = argv.arguments! unless argv.arguments.empty?
        config.silent = false
        super
      end

      def validate!
        super
        help! "A search query is required." unless @query
      end

      def run
        if @web
          web_search
        else
          local_search
        end
      end

      extend Executable
      executable :open

      def web_search
        query_parameter = [
          ('on%3Aosx' if @supported_on_osx),
          ('on%3Aios' if @supported_on_ios),
          @query
        ].compact.flatten.join('%20')
        url = "http://cocoapods.org/?q=#{query_parameter}"
        UI.puts("Opening #{url}")
        open!(url)
      end

      def local_search
        sets = SourcesManager.search_by_name(@query.join(' ').strip, @full_text_search)
        if @supported_on_ios
          sets.reject!{ |set| !set.specification.available_platforms.map(&:name).include?(:ios) }
        end
        if @supported_on_osx
          sets.reject!{ |set| !set.specification.available_platforms.map(&:name).include?(:osx) }
        end

        statistics_provider = Config.instance.spec_statistics_provider
        sets.each do |set|
          begin
            if @stats
              UI.pod(set, :stats, statistics_provider)
            else
              UI.pod(set, :normal)
            end
          rescue DSLError
            UI.warn "Skipping `#{set.name}` because the podspec contains errors."
          end
        end
      end

    end
  end
end
