module Pod
  class Command
    class Install < Command
      include ProjectDirectory

      self.summary = 'Install project dependencies to Podfile.lock versions'

      self.description = <<-DESC
        Downloads all dependencies defined in `Podfile` and creates an Xcode
        Pods library project in `./Pods`.

        The Xcode project file should be specified in your `Podfile` like this:

            project 'path/to/XcodeProject'

        If no project is specified, then a search for an Xcode project will
        be made. If more than one Xcode project is found, the command will
        raise an error.

        This will configure the project to reference the Pods static library,
        add a build configuration file, and add a post build script to copy
        Pod resources.
      DESC

      def self.options
        [
          ['--repo-update', 'Force running `pod repo update` before install'],
        ].concat(super)
      end

      def initialize(argv)
        config.skip_repo_update = !argv.flag?('repo-update', false)
        super
      end

      def run
        verify_podfile_exists!
        installer = installer_for_config
        installer.update = false
        installer.install!
      end
    end
  end
end
