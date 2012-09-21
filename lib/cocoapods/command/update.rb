module Pod
  class Command
    class Update < Install
      def self.banner
%{Updating dependencies of a project:

    $ pod update

      Updates all dependencies.}
      end

      def self.options
        [["--no-update", "Skip running `pod repo update` before install"]].concat(super)
      end

      def initialize(argv)
        config.skip_repo_update = argv.option('--no-update')
        super unless argv.empty?
      end

      def run
        verify_podfile_exists!
        verify_lockfile_exists!
        run_install_with_update(true)
      end
    end
  end
end

