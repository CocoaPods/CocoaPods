module Pod
  class Command
    class Update < Install
      def self.banner
%{Updating dependencies of a project:

    $ pod update

      Updates all dependencies.}
      end

      def run
        verify_podfile_exists!
        verify_lockfile_exists!
        update_spec_repos_if_necessary!
        run_install_with_update(true)
      end
    end
  end
end

