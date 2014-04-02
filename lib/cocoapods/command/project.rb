module Pod
  class Command

    # Provides support the common behaviour of the `install` and `update`
    # commands.
    #
    module Project
      module Options
        def options
          [
            ["--no-clean",       "Leave SCM dirs like `.git' and `.svn' intact after downloading"],
            ["--no-integrate",   "Skip integration of the Pods libraries in the Xcode project(s)"],
            ["--no-repo-update", "Skip running `pod repo update` before install"],
          ].concat(super)
        end
      end

      def self.included(base)
        base.extend Options
      end

      def initialize(argv)
        config.clean = argv.flag?('clean', config.clean)
        config.integrate_targets = argv.flag?('integrate', config.integrate_targets)
        config.skip_repo_update = !argv.flag?('repo-update', !config.skip_repo_update)
        super
      end

      # Runs the installer.
      #
      # @param  [Hash, Boolean, nil] update
      #         Pods that have been requested to be updated or true if all Pods
      #         should be updated
      #
      # @return [void]
      #
      def run_install_with_update(update)
        installer = Installer.new(config.sandbox, config.podfile, config.lockfile)
        installer.update = update
        installer.install!
      end
    end

    #-------------------------------------------------------------------------#

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

    #-------------------------------------------------------------------------#

    class Update < Command
      include Project

      self.summary = 'Update outdated project dependencies'

      self.description = <<-DESC
        Updates the Pods identified by the specified POD_NAMES. If no POD_NAMES are
        specified it updates all the Pods ignoring the contents of the Podfile.lock.
        This command is reserved to the update of dependencies and pod install should
        be used to install changes to the Podfile.
      DESC

      self.arguments = '[POD_NAMES...]'

      def initialize(argv)
        @pods = argv.arguments! unless argv.arguments.empty?
        super
      end

      def run
        verify_podfile_exists!

        if @pods
          verify_lockfile_exists!

          # Check if all given pods are installed
          missing_pods = @pods.select { |pod| !config.lockfile.pod_names.include?(pod) }
          if missing_pods.length > 0
            raise Informative, (missing_pods.length > 1 \
              ? "Pods %s are not installed and cannot be updated" \
              : "Pod %s is not installed and cannot be updated"
            ) % missing_pods.map { |p| "`#{p}'" }.join(', ')
          end

          run_install_with_update(:pods => @pods)
        else
          UI.puts "Update all pods".yellow unless @pods
          run_install_with_update(true)
        end
      end
    end

  end
end

