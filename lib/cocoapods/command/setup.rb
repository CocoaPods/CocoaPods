module Pod
  class Command
    class Setup < Command
      def self.banner
%{Setup CocoaPods environment:

    $ pod setup

      Creates a directory at `~/.cocoapods' which will hold your spec-repos.
      This is where it will create a clone of the public `master' spec-repo from:

          https://github.com/CocoaPods/Specs

      If the clone already exists, it will ensure that it points to the correct
      remote.}
      end

      def initialize(argv)
        super unless argv.empty?
      end

      def master_repo_url
        'git://github.com/CocoaPods/Specs.git'
      end

      def add_master_repo_command
        @command ||= Repo.new(ARGV.new(['add', 'master', master_repo_url]))
      end

      def update_master_repo_remote_command
        @command ||= Repo.new(ARGV.new(['set-url', 'master', master_repo_url]))
      end

      def run
        if (config.repos_dir + 'master').exist?
          update_master_repo_remote_command.run
        else
          add_master_repo_command.run
        end
      end
    end
  end
end
