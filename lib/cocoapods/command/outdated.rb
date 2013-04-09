module Pod
  class Command
    class Outdated < Command
      self.summary = 'Show outdated project dependencies'

      self.description = <<-DESC
        Shows the outdated pods in the current Podfile.lock, but only those from
        spec repos, not those from local/external sources or `:head` versions.
      DESC

      def self.options
        [["--no-repo-update", "Skip running `pod repo update` before install"]].concat(super)
      end

      def initialize(argv)
        config.skip_repo_update = argv.flag?('repo-update', config.skip_repo_update)
        super
      end

      # @todo the command report new dependencies added to the Podfile as
      #       updates.
      #
      # @todo fix.
      #
      def run
        verify_podfile_exists!
        verify_lockfile_exists!

        lockfile = config.lockfile
        pods = lockfile.pod_names
        updates = []
        pods.each do |pod_name|
          set = SourcesManager.search(Dependency.new(pod_name))
          next unless set
          source_version = set.versions.first
          lockfile_version = lockfile.version(pod_name)
          if source_version > lockfile_version
            updates << [pod_name, lockfile_version, source_version]
          end
        end

        if updates.empty?
          UI.puts "No updates are available.".yellow
        else
          UI.section "The following updates are available:" do
            updates.each do |(name, from_version, to_version)|
              UI.puts "- #{name} #{from_version} -> #{to_version}"
            end
          end
        end
      end
    end
  end
end


