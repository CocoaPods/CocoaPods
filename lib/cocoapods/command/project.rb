module Pod
  class Command
    module Project
      module Options
        def options
          [
            ["--no-clean",     "Leave SCM dirs like `.git' and `.svn' intact after downloading"],
            ["--no-doc",       "Skip documentation generation with appledoc"],
            ["--no-integrate", "Skip integration of the Pods libraries in the Xcode project(s)"],
            ["--no-update",    "Skip running `pod repo update` before install"],
          ].concat(super)
        end
      end

      def self.included(base)
        base.extend Options
      end

      def initialize(argv)
        config.clean             = argv.flag?('clean', true)
        config.generate_docs     = argv.flag?('doc', true)
        config.integrate_targets = argv.flag?('integrate', true)
        config.skip_repo_update  = !argv.flag?('update', true)
        super
      end

      def run_install_with_update(update)
        sandbox   = Sandbox.new(config.project_pods_root)
        installer = Installer.new(sandbox, config.podfile, config.lockfile)
        installer.update_mode = update
        installer.install!
      end
    end

    class Install < Command
      include Project

      self.summary = 'Install project dependencies'

      self.description = <<-DESC
        Downloads all dependencies defined in `Podfile' and creates an Xcode
        Pods library project in `./Pods'.

        The Xcode project file should be specified in your `Podfile` like this:

          xcodeproj 'path/to/XcodeProject'

        If no xcodeproj is specified, then a search for an Xcode project will
        be made.  If more than one Xcode project is found, the command will
        raise an error.

        This will configure the project to reference the Pods static library,
        add a build configuration file, and add a post build script to copy
        Pod resources.
      DESC

      def run
        verify_podfile_exists!
        run_install_with_update(false)
      end
    end

    class Update < Command
      include Project

      self.summary = 'Update outdated project dependencies'

      def run
        verify_podfile_exists!
        verify_lockfile_exists!
        run_install_with_update(true)
      end
    end

  end
end

