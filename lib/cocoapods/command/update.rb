module Pod
  class Command
    class Update < Command
      def self.banner
%{Updating dependencies of a project:

    $ pod update

      Updates all dependencies.}
      end

      def self.options
        [
          ["--no-clean",     "Leave SCM dirs like `.git' and `.svn' intact after downloading"],
          ["--no-doc",       "Skip documentation generation with appledoc"],
          ["--no-integrate", "Skip integration of the Pods libraries in the Xcode project(s)"],
          ["--no-update",    "Skip running `pod repo update` before install"],
        ].concat(super)
      end

      def initialize(argv)
        config.clean             = !argv.option('--no-clean')
        config.generate_docs     = !argv.option('--no-doc')
        config.integrate_targets = !argv.option('--no-integrate')
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
        Installer.new(resolver).install!
      end
    end
  end
end

