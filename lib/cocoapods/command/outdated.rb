module Pod
  class Command
    class Outdated < Command
      def self.banner
%{Updates dependencies of a project:

    $ pod outdated

      Show all of the outdated pods in the current Podfile.lock. }
      end

      def self.options
        [
          ["--no-update",    "Skip running `pod repo update` before install"],
        ].concat(super)
      end

      def initialize(argv)
        @update_repo             = !argv.option('--no-update')
        super unless argv.empty?
      end

      def run
        unless podfile = config.podfile
          raise Informative, "No `Podfile' found in the current working directory."
        end
        unless lockfile = config.lockfile
          raise Informative, "No `Podfile.lock' found in the current working directory, run `pod install'."
        end

        if @update_repo
          print_title 'Updating Spec Repositories', true
          Repo.new(ARGV.new(["update"])).run
        end

        sandbox = Sandbox.new(config.project_pods_root)
        resolver = Resolver.new(podfile, lockfile, sandbox)
        resolver.update_mode = true
        resolver.update_external_specs = false
        resolver.resolve
        pods_to_install = resolver.pods_to_install
        external_pods   = resolver.pods_from_external_sources

        known_update_specs = []
        head_mode_specs = []
        resolver.specs.each do |s|
          next if external_pods.include?(s.name)
          next unless pods_to_install.include?(s.name)

          if s.version.head?
            head_mode_specs << s.name
          else
            known_update_specs << s.to_s
          end
        end

        if pods_to_install.empty?
          puts "\nNo updates are available.\n".yellow
        else

          unless known_update_specs.empty?
            puts "\nThe following updates are available:".green
            puts "  - " << known_update_specs.join("\n  - ") << "\n"
          end

          unless head_mode_specs.empty?
            puts "\nThe following pods might present updates as they are in head mode:".green
            puts "  - " << head_mode_specs.join("\n  - ") << "\n"
          end

          unless (external_pods).empty?
            puts "\nThe following pods might present updates as they loaded from an external source:".green
            puts "  - " << external_pods.join("\n  - ") << "\n"
          end
          puts
        end
      end
    end
  end
end


