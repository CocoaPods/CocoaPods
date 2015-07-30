module Pod
  class Command
    class Check < Command
      self.summary = 'Quickly check if pods are installed'
      self.description = <<-DESC
Determine whether the requirements for your application are satisfied.
The `check` command will quickly compare the installed Pods against the
dependencies specified in Podfile.lock. The `check` command will exit with
status 0 when the pods are up to date and status 1 otherwise.
The `check` can be chained with the install command in the following way to
determine if installation is necessary.

    $ pod check || pod install
DESC


      def run
        unless config.lockfile
          raise Informative, 'No `Podfile.lock` found in the project directory, run `pod install`.'
        end

        unless config.lockfile == config.sandbox.manifest
          raise Informative, 'Some dependencies are not met. Run `pod install` or update your CocoaPods installation.'
        end
        UI.notice('The applications\'s dependencies are satisfied.')
      end

    end
  end
end
