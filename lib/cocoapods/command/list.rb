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

      def last_check_file
        config.repos_dir + 'list_new'
      end

      def update_last_check_time(time)
        File.open(last_check_file, 'w') {|f| f.write(time)}
      end

      def last_check_time
        if File.exists?(last_check_file)
          string = File.open(last_check_file, "rb").read
          Time.parse(string)
        else
          Time.now - 60 * 60 * 24 * 15
        end
      end

      def new_sets_since(time)
        all = Source.all_sets
        all.reject! {|set| (set.creation_date  - time).to_i <= 0 }
        all.sort_by {|set| set.creation_date}
      end

      def list_new
        time = last_check_time
        time_string = time.strftime("%A %m %B %Y (%H:%M)")
        sets = new_sets_since(time)
        if sets.empty?
          puts "\nNo new pods were added since #{time.localtime}" unless list
        else
          present_sets(sets)
          update_last_check_time(sets.last.creation_date)
          puts "#{sets.count} new pods were added since #{time_string}" unless list
        end
        puts
      end

      def list_all
        present_sets(all = Source.all_sets)
        puts "#{all.count} pods were found"
        puts
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
