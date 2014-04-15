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

        if updates.empty?
          UI.puts "No updates are available.".yellow
        else
          UI.section "The following updates are available:" do
            updates.each do |(name, from_version, to_version)|
              UI.puts "- #{name} #{from_version} -> #{to_version}"
            end
          end
        end

        if deprecated_pods.any?
          UI.section 'The following pods are deprecated:' do
            deprecated_pods.each do |spec|
              if spec.deprecated_in_favor_of
                UI.puts "- #{spec.name}" \
                  " (in favor of #{spec.deprecated_in_favor_of})"
              else
                UI.puts "- #{spec.name}"
              end
            end
          end
        end

      end

      private

      def updates
        @updates ||= begin
          spec_sets.map do |set|
            spec = set.specification
            source_version = set.versions.first
            pod_name = spec.name
            lockfile_version = lockfile.version(pod_name)
            if source_version > lockfile_version
              [pod_name, lockfile_version, source_version]
            else
              nil
            end
          end.compact.uniq
        end
      end

      def deprecated_pods
        @deprecated_pods ||= begin
          spec_sets.map(&:specification).select do |spec|
            spec.deprecated || spec.deprecated_in_favor_of
          end.compact.uniq
        end
      end

      def spec_sets
        @spec_sets ||= begin
          installed_pods.map do |pod_name|
            SourcesManager.search(Dependency.new(pod_name))
          end.compact.uniq
        end
      end

      def installed_pods
        @installed_pods ||= begin
          verify_podfile_exists!

          lockfile.pod_names
        end
      end

      def lockfile
        @lockfile ||= begin
          verify_lockfile_exists!
          config.lockfile
        end
      end

    end
  end
end


