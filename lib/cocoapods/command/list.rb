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
        SetPresent.set_present_options +
        super
      end

      include SetPresent
      extend Executable
      executable :git

      def initialize(argv)
        parse_set_options(argv)
        @days = argv.arguments.first
        unless @days == nil || @days =~ /^[0-9]+$/
          super
        end
      end

      def dir
        config.repos_dir + 'master'
      end

      def dir_list_from_commit(commit)
        Dir.chdir(dir) { git("ls-tree --name-only -r #{commit}") }
      end

      def commit_from_days_ago (days)
        Dir.chdir(dir) { git("rev-list -n1 --before=\"#{days} day ago\" --first-parent master") }
      end

      def spec_names_from_commit (commit)
        dir_list = dir_list_from_commit(commit)

        # Keep only subdirectories
        dir_list.gsub!(/^[^\/]*$/,'')
        # Keep only subdirectories name
        dir_list.gsub!(/(.*)\/[0-9].*/,'\1')

        result = dir_list.split("\n").uniq
        result.delete('')
        puts
        puts commit.white
        puts result.join(', ').magenta
        result
      end

      def new_specs_set(commit)
        #TODO: find the changes for all repos
        new_specs = spec_names_from_commit('HEAD') - spec_names_from_commit(commit)
        sets = all_specs_set.select { |set| new_specs.include?(set.name) }
      end

      def all_specs_set
        result = []
        Source.all.each do |source|
          source.pod_sets.each do |set|
            result << set
          end
        end
        result
      end

      def list_new
        sets = new_specs_set(commit_from_days_ago(@days))
        present_sets(sets)
        if !list
          if sets.count != 0
            puts "#{sets.count} new pods were added in the last #{@days} days"
            puts
          else
            puts "No new pods were added in the last #{@days} days"
            puts
          end
        end
      end

      def list_all
        present_sets(all_specs_set)
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
