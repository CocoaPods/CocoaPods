module Pod
  class Command
    class Install < Command
      def self.banner
%{Installing dependencies of a project:

    $ pod install

      Downloads all dependencies defined in `Podfile' and creates an Xcode
      Pods library project in `./Pods'.

      The Xcode project file should be specified in your `Podfile` like this:

        xcodeproj 'path/to/project.xcodeproj'

      If no xcodeproj is specified, then a search for an Xcode project will
      be made.  If more than one Xcode project is found, the command will
      raise an error.

      This will configure the project to reference the Pods static library,
      add a build configuration file, and add a post build script to copy
      Pod resources.
}
      end

      def self.options
        [
          ["--no-clean",     "Leave SCM dirs like `.git' and `.svn' in tact after downloading"],
          ["--no-doc",       "Skip documentation generation with appledoc"],
          ["--force-doc",    "Force the generation of documentation"],
          ["--no-integrate", "Skip integration of the Pods libraries in the Xcode project(s)"],
          ["--no-update",    "Skip running `pod repo update` before install"],
        ].concat(super)
      end

      def initialize(argv)
        config.clean             = !argv.option('--no-clean')
        config.doc               = !argv.option('--no-doc')
        config.force_doc         =  argv.option('--force-doc')
        config.integrate_targets = !argv.option('--no-integrate')
        @update_repo             = !argv.option('--no-update')
        super unless argv.empty?
      end

      def run
        unless podfile = config.podfile
          raise Informative, "No `Podfile' found in the current working directory."
        end

        if config.integrate_targets?
          # TODO this should be done for all targets (?)
          unless xcodeproj = podfile.target_definitions[:default].xcodeproj
            raise Informative, "Please specify a valid xcodeproj path in your Podfile.\n\n" +
              "Usage:\n\t" +
              "xcodeproj 'path/to/project.xcodeproj'"
          end

          if xcodeproj && !xcodeproj.exist?
            raise Informative, "The specified project `#{xcodeproj}' does not exist."
          end
        end

        if @update_repo
          puts "\nUpdating Spec Repositories\n".yellow if config.verbose?
          Repo.new(ARGV.new(["update"])).run
        end

        Installer.new(podfile).install!
      end
    end
  end
end
