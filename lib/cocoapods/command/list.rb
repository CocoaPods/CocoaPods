require 'time'
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
        SetPresent.set_present_options +
          super
      end

      include SetPresent
      extend Executable
      executable :git

      def initialize(argv)
        parse_set_options(argv)
        @new = argv.option('new')
        super unless argv.empty?
      end

      def list_all
        present_sets(all = Source.all_sets)
        puts "#{all.count} pods were found"
        puts
      end

      def list_new
        days = [1,2,3,5,8]
        dates, groups = {}, {}
        days.each {|d| dates[d] = Time.now - 60 * 60 * 24 * d}
        Source.all_sets.sort_by {|set| set.creation_date}.each do |set|
          set_date = set.creation_date
          days.each do |d|
            if set_date > dates[d]
              groups[d] = [] unless groups[d]
              groups[d] << set
              break
            end
          end
        end
        puts
        days.reverse.each do |d|
          sets = groups[d]
          next unless sets
          puts "Pods added in the last #{d == 1 ? '1 day' : "#{d} days"}\n".yellow
          present_sets(sets)
        end
      end

      def run
        if @new
          puts "\nUpdating Spec Repositories\n".yellow if config.verbose?
          Repo.new(ARGV.new(["update"])).run
          list_new
        else
          list_all
        end
      end
    end
  end
end
