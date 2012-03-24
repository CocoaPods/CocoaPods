module Pod
  class Command
    class List < Command
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

      include DisplayPods
      extend Executable
      executable :git

      def initialize(argv)
        @stats = argv.option('--stats')
        #TODO: accept only integers
        @days = argv.arguments.first
      end

      def dir
        File.expand_path '~/.cocoapods/master'
      end

      def list_directory_at_commit(commit)
        Dir.chdir(dir) { git("ls-tree --name-only -r #{commit}") }
      end

      def commit_at_days_ago (days)
        return 'HEAD' if days == 0
        Dir.chdir(dir) { git("rev-list -n1 --before=\"#{days} day ago\" master") }
      end

      def pods_at_days_ago (days)
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
        #TODO: find the changes for all repos
        new_pods = pods_at_days_ago(0) - pods_at_days_ago(@days)
        sets = all_pods_sets.select {|set| new_pods.include?(set.name) }

        puts
        if sets.count != 0
          puts "#{sets.count} new pods were added in the last #{@days} days"
          puts
          display_pod_list(sets, @stats)
        else
          puts "No new pods were added in the last #{@days} days"
        end
        puts
      end

      def list_all
        display_pod_list(all_pods_sets, @stats)
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
