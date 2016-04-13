module Pod
  class Command
    class List < Command
      self.summary = 'List pods'
      self.description = 'Lists all available pods.'

      def self.options
        [
          ['--update', 'Run `pod repo update` before listing'],
          ['--stats',  'Show additional stats (like GitHub watchers and forks)'],
        ].concat(super)
      end

      def initialize(argv)
        @update = argv.flag?('update')
        @stats  = argv.flag?('stats')
        super
      end

      def run
        update_if_necessary!

        sets = config.sources_manager.aggregate.all_sets
        sets.each { |set| UI.pod(set, :name_and_version) }
        UI.puts "\n#{sets.count} pods were found"
      end

      def update_if_necessary!
        if @update && config.verbose?
          UI.section("\nUpdating Spec Repositories\n".yellow) do
            Repo.new(ARGV.new(['update'])).run
          end
        end
      end

      #-----------------------------------------------------------------------#
    end
  end
end
