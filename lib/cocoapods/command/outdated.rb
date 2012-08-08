module Pod
  class Command
    class Outdated < Command
      def self.banner
%{Updates dependencies of a project:

    $ pod outdated

      Shows the dependencies that would be installed by `pod update'. }
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

        # if @update_repo
        #   print_title 'Updating Spec Repositories', true
        #   Re"o.new(ARGV.new(["update"])).run
        # end

        sandbox = Sandbox.new(config.project_pods_root)
        resolver = Resolver.new(podfile, lockfile, sandbox)
        resolver.update_mode = true
        resolver.resolve
        specs_to_install = resolver.specs_to_install
        if specs_to_install.empty?
          puts "\nNo updates are available.\n".yellow
        else
          puts "\nThe following updates are available:".green
          puts "  - " << specs_to_install.join("\n  - ") << "\n\n"
        end
      end
    end
  end
end


