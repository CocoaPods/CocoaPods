module Pod
  class Command
    class List < Command
      self.summary = 'List pods'
      self.description = 'Lists all available pods.'

      def self.options
        [[
          '--update', 'Run `pod repo update` before listing',
          '--stats',  'Show additional stats (like GitHub watchers and forks)'
        ]].concat(super)
      end

      def initialize(argv)
        @update = argv.flag?('update')
        @stats  = argv.flag?('stats')
        super
      end

      def run
        update_if_necessary!

        sets = SourcesManager.aggregate.all_sets
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

      class New < List
        self.summary = 'Lists pods introduced in the master spec-repo since the last check'

        def run
          update_if_necessary!

          days = [1, 2, 3, 5, 8]
          dates, groups = {}, {}
          days.each { |d| dates[d] = Time.now - 60 * 60 * 24 * d }
          sets = SourcesManager.aggregate.all_sets
          statistics_provider = Config.instance.spec_statistics_provider
          creation_dates = statistics_provider.creation_dates(sets)

          sets.each do |set|
            set_date = creation_dates[set.name]
            days.each do |d|
              if set_date >= dates[d]
                groups[d] = [] unless groups[d]
                groups[d] << set
                break
              end
            end
          end
          days.reverse.each do |d|
            sets = groups[d]
            next unless sets
            UI.section("\nPods added in the last #{'day'.pluralize(d)}".yellow) do
              sorted = sets.sort_by { |s| creation_dates[s.name] }
              mode = @stats ? :stats : :name
              sorted.each { |set| UI.pod(set, mode, statistics_provider) }
            end
          end
        end
      end
    end
  end
end
