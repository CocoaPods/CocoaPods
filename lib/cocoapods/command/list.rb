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
        SetPresent.options + super
      end

      extend Executable
      executable :git

      def initialize(argv)
        @new = argv.option('new')
        @presenter = Presenter.new(argv)
        super unless argv.empty?
      end

      def list_all
        @presenter.present_sets(all = Source.all_sets)
        puts "#{all.count} pods were found"
        puts
      end

      def list_new
        days = [1,2,3,5,8]
        dates, groups = {}, {}
        days.each {|d| dates[d] = Time.now - 60 * 60 * 24 * d}
        Source.all_sets.each do |set|
          set_date = Pod::Specification::Statistics.new(set).creation_date
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
          puts "Pods added in the last #{d == 1 ? '1 day' : "#{d} days"}".yellow
          @presenter.present_sets(sets.sort_by {|set| Pod::Specification::Statistics.new(set).creation_date})
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
