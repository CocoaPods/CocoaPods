module Pod
  class Command
    class Update < Command
      include RepoUpdate
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
          ['--sources=https://github.com/artsy/Specs,master', 'The sources from which to update dependent pods. ' \
           'Multiple sources must be comma-delimited. The master repo will not be included by default with this option.'],
        ].concat(super)
      end

      def initialize(argv)
        @pods = argv.arguments! unless argv.arguments.empty?

        source_urls = argv.option('sources', '').split(',')
        unless source_urls.empty?
          source_pods = source_urls.flat_map { |url| config.sources_manager.source_with_name_or_url(url).pods }
          unless source_pods.empty?
            source_pods = source_pods.select { |pod| config.lockfile.pod_names.include?(pod) }
            if @pods
              @pods += source_pods
            else
              @pods = source_pods unless source_pods.empty?
            end
          end
        end

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
        installer.repo_update = repo_update?(:default => true)
        if @pods
          verify_lockfile_exists!
          verify_pods_are_installed!
          installer.update = { :pods => @pods }
        else
          UI.puts 'Update all pods'.yellow
          installer.update = true
        end
        installer.install!
      end
    end
  end
end
