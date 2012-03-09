module Pod
  class Command
    class Install < Command
      def self.banner
%{Installing dependencies of a project:

    $ pod install

      Downloads all dependencies defined in `Podfile' and creates an Xcode
      Pods library project in `./Pods'.

      The Xcode project file should be specified in your `Podfile` like this:

      xcodeproj path/to/project.xcodeproj

      If no xcodeproj is specified, then a search for an Xcode project will
      be made.  If more than one Xcode project is found, the command will
      raise an error.

      This will configure the project to reference the Pods static library,
      add a build configuration file, and add a post build script to copy
      Pod resources.
}
      end

      def self.options
        "    --no-clean  Leave SCM dirs like `.git' and `.svn' in tact after downloading\n" +
        "    --no-update Skip running `pod repo update` before install\n" +
        super
      end

      def initialize(argv)
        config.clean = !argv.option('--no-clean')
        @update_repo = !argv.option('--no-update')
        super unless argv.empty?
      end

      def run
        unless podfile = config.rootspec
          raise Informative, "No `Podfile' found in the current working directory."
        end

        if podfile.xcodeproj.nil?
          raise Informative, "Please specify a valid xcodeproj path in your Podfile.\n\n" +
            "Usage:\n\t" +
            "xcodeproj 'path/to/project.xcodeproj'"
        end

        unless File.exist?(podfile.xcodeproj)
          raise Informative, "The specified project `#{podfile.xcodeproj}' does not exist."
        end

        if @update_repo
          Repo.new(ARGV.new(["update"])).run
        end
        installer = Installer.new(podfile)
        installer.install!

        ProjectIntegration.integrate_with_project(podfile.xcodeproj)
      end
    end
  end
end
