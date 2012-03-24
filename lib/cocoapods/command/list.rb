module Pod
  class Command
    class List < Command
      include DisplayPods

      def self.banner
        %{List all pods:

    $ pod list

      Lists all available pods.

    $ pod list [DAYS]

      Lists the pods introduced in the master repo since the given number of days.}
      end

      def self.options
        "    --stats     Show additional stats (like GitHub watchers and forks)\n" +
        super
      end

      def initialize(argv)
        @stats = argv.option('--stats')
        @days = argv.arguments.first
      end

      def list_all
        display_pod_list(all_pods_sets, @stats)
      end

      def dir
        File.expand_path '~/.cocoapods/master'
      end

      def list_directory_at_commit(commit)
        Dir.chdir(dir) do |_|
          `git ls-tree --name-only -r #{commit}`
        end
      end

      def commit_at_days_ago (days)
        return 'HEAD' if days == 0
        Dir.chdir(dir) do |_|
          `git rev-list -n1 --before="#{days} day ago" master`
        end
      end

      def pods_at_days_ago (days = 7)
        commit = commit_at_days_ago(days)
        dir_list = list_directory_at_commit(commit)
        # Keep only directories
        dir_list.gsub!(/^[^\/]*$/,'')
        #Clean pod names
        dir_list.gsub!(/(.*)\/[0-9].*/,'\1')

        result = dir_list.split("\n").uniq
        result.delete('')
        result
      end

      def all_pods_sets
        result = []
        Source.all.each do |source|
          source.pod_sets.each do |set|
            result << set
          end
        end
        result
      end

      def list_new
        pods_past = pods_at_days_ago(@days)
        pods_now = pods_at_days_ago(0)
        pods_diff = pods_now - pods_past

        sets = all_pods_sets.select {|set| pods_diff.include?(set.name) }
        puts
        if pods_diff.count
          puts "#{pods_diff.count} new pods were added in the last #{@days} days\n"
          puts
          display_pod_list(sets, @stats)
        else
          puts "No new pods".red
        end
        puts
      end

      def run
        if @days
          list_new
        else
          list_all
        end
      end
    end
  end
end
