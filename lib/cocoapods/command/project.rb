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

    #-------------------------------------------------------------------------#

    class Update < Command
      include ProjectDirectory

      self.summary = 'Update outdated project dependencies and create new ' \
        'Podfile.lock'

      self.description = <<-DESC
        Updates the Pods identified by the specified `POD_NAMES`. If no
        `POD_NAMES` are specified it updates all the Pods ignoring the contents
        of the Podfile.lock.
        This command is reserved to the update of dependencies and pod install
        should be used to install changes to the Podfile.
      DESC

      self.arguments = [
        CLAide::Argument.new('POD_NAMES', false, true),
      ]

      def self.options
        [
          ['--no-repo-update', 'Skip running `pod repo update` before install'],
        ].concat(super)
      end

      def initialize(argv)
        config.skip_repo_update = !argv.flag?('repo-update', !config.skip_repo_update)
        @pods = argv.arguments! unless argv.arguments.empty?
        super
      end

      # Check if all given pods are installed
      #
      def verify_pods_are_installed!
        lockfile_roots = config.lockfile.pod_names.map { |p| Specification.root_name(p) }
        missing_pods = @pods.map { |p| Specification.root_name(p) }.select do |pod|
          !lockfile_roots.include?(pod)
        end

        unless missing_pods.empty?
          message = if missing_pods.length > 1
                      "Pods `#{missing_pods.join('`, `')}` are not " \
                          'installed and cannot be updated'
                    else
                      "The `#{missing_pods.first}` Pod is not installed " \
                          'and cannot be updated'
                    end
          raise Informative, message
        end
      end

      def run
        verify_podfile_exists!

        installer = installer_for_config
        if @pods
          verify_lockfile_exists!
          verify_pods_are_installed!
          installer.update = { :pods => @pods }
        else
          UI.puts 'Update all pods'.yellow unless @pods
          installer.update = true
        end
        installer.install!
      end
    end
  end
end
