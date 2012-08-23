module Pod
  class Command
    class Install < Command
      def self.banner
%{Installing dependencies of a project:

    $ pod install

      Downloads all dependencies defined in `Podfile' and creates an Xcode
      Pods library project in `./Pods'.

      The Xcode project file should be specified in your `Podfile` like this:

        xcodeproj 'path/to/XcodeProject'

      If no xcodeproj is specified, then a search for an Xcode project will
      be made.  If more than one Xcode project is found, the command will
      raise an error.

      This will configure the project to reference the Pods static library,
      add a build configuration file, and add a post build script to copy
      Pod resources.}
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

      def run_install_with_update(update)
        sandbox = Sandbox.new(config.project_pods_root)
        resolver = Resolver.new(config.podfile, config.lockfile, sandbox)
        resolver.update_mode = update
        Installer.new(resolver).install!
      end

      def run
        verify_podfile_exists!
        update_spec_repos_if_necessary!
        run_install_with_update(false)
      end
    end
  end
end
