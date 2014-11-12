module Pod
  class Command
    class Search < Command
      self.summary = 'Searches for pods'

      self.description = <<-DESC
        Searches for pods, ignoring case, whose name matches `QUERY`. If the
        `--full` option is specified, this will also search in the summary and
        description of the pods.
      DESC

      self.arguments = [
        CLAide::Argument.new('QUERY', true),
      ]

      def self.options
        [
          ['--regex', 'Interpret the `QUERY` as a regular expression'],
          ['--full',  'Search by name, summary, and description'],
          ['--stats', 'Show additional stats (like GitHub watchers and forks)'],
          ['--ios',   'Restricts the search to Pods supported on iOS'],
          ['--osx',   'Restricts the search to Pods supported on OS X'],
          ['--web',   'Searches on cocoapods.org'],
        ].concat(super.reject { |option, _| option == '--silent' })
      end

      def initialize(argv)
        @use_regex = argv.flag?('regex')
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
        help! 'A search query is required.' unless @query

        unless @web || !@use_regex
          begin
            /#{@query.join(' ').strip}/
          rescue RegexpError
            help! 'A valid regular expression is required.'
          end
        end
      end

      def run
        ensure_master_spec_repo_exists!
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
          ('on:osx' if @supported_on_osx),
          ('on:ios' if @supported_on_ios),
          @query,
        ].compact.flatten.join(' ')
        url = "http://cocoapods.org/?q=#{CGI.escape(query_parameter).gsub('+', '%20')}"
        UI.puts("Opening #{url}")
        open!(url)
      end

      def local_search
        query_regex = @query.join(' ').strip
        query_regex = Regexp.escape(query_regex) unless @use_regex

        sets = SourcesManager.search_by_name(query_regex, @full_text_search)
        if @supported_on_ios
          sets.reject! { |set| !set.specification.available_platforms.map(&:name).include?(:ios) }
        end
        if @supported_on_osx
          sets.reject! { |set| !set.specification.available_platforms.map(&:name).include?(:osx) }
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
