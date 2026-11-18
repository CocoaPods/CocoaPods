module Pod
  class Command
    class List < Command
      include ProjectDirectory

      self.summary = 'List pods'
      self.description = 'Lists all available pods.'

      def self.options
        [
          ['--update', 'Run `pod repo update` before listing'],
          ['--stats',  'Show additional stats (like GitHub watchers and forks)'],
          ['--installed', 'List only installed pods from the current project'],
        ].concat(super)
      end

      def initialize(argv)
        @update = argv.flag?('update')
        @stats  = argv.flag?('stats')
        @installed = argv.flag?('installed')
        super
      end

      def run
        if @installed
          list_installed_pods
        else
          list_all_pods
        end
      end

      def list_all_pods
        update_if_necessary!

        sets = config.sources_manager.aggregate.all_sets
        sets.each { |set| UI.pod(set, :name_and_version) }
        UI.puts "\n#{sets.count} pods were found"
      end

      def list_installed_pods
        verify_podfile_exists!
        verify_lockfile_exists!

        lockfile = config.lockfile
        pod_names = lockfile.pod_names.sort

        if pod_names.empty?
          UI.puts 'No pods are installed.'.yellow
        else
          UI.section 'Installed pods:' do
            pod_names.each do |pod_name|
              version = lockfile.version(pod_name)
              UI.puts "- #{pod_name} #{version}"
            end
          end
          UI.puts "\n#{pod_names.count} #{'pod'.pluralize(pod_names.count)} installed"
        end
      end

      def update_if_necessary!
        UI.section("\nUpdating Spec Repositories\n".yellow) do
          Repo::Update.new(CLAide::ARGV.new([])).run
        end if @update
      end

      #-----------------------------------------------------------------------#
    end
  end
end
