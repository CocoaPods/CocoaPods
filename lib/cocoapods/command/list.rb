module Pod
  class Command
    class List < Command
      def self.banner
        %{List all pods:

    $ pod list

      Lists all available pods.

    $ pod list new

      Lists the pods introduced in the master repository since the last check.}
      end

      def self.options
        [[
          "--update", "Run `pod repo update` before listing",
          "--stats",  "Show additional stats (like GitHub watchers and forks)"
        ]].concat(super)
      end

      extend Executable
      executable :git

      def initialize(argv)
        @update = argv.option('--update')
        @stats  = argv.option('--stats')
        @new    = argv.option('new')
        super unless argv.empty?
      end

      def list_all
        sets = Source.all_sets
        sets.each { |set| UI.pod(set, :name) }
        UI.puts "\n#{sets.count} pods were found"
      end

      def list_new
        days = [1,2,3,5,8]
        dates, groups = {}, {}
        days.each {|d| dates[d] = Time.now - 60 * 60 * 24 * d}
        sets = Source.all_sets
        creation_dates = Pod::Specification::Statistics.instance.creation_dates(sets)

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
          UI.section("\nPods added in the last #{d == 1 ? 'day' : "#{d} days"}".yellow) do
            sorted = sets.sort_by {|s| creation_dates[s.name]}
            sorted.each { |set| UI.pod(set, (@stats ? :stats : :name)) }
          end
        end
      end

      def run
        UI.section("\nUpdating Spec Repositories\n".yellow) do
          Repo.new(ARGV.new(["update"])).run
        end if @update && config.verbose?
        @new ? list_new : list_all
      end
    end
  end
end
