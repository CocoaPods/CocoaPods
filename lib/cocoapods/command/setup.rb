module Pod
  class Command
    class Setup < Command
      def self.banner
%{Setup CocoaPods environment:

    $ pod setup

      Creates a directory at `~/.cocoapods' which will hold your spec-repos.
      This is where it will create a clone of the public `master' spec-repo from:

          https://github.com/CocoaPods/Specs}
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

      def run
        add_master_repo_command.run
      end
    end
  end
end
