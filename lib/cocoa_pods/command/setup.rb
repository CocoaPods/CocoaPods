module Pod
  class Command
    class Setup < Command
      def self.banner
%{### Setup CocoaPods environment

    $ pod setup

      Creates a directory at `~/.cocoa-pods' which will hold your spec-repos.
      This is where it will create a clone of the public `master' spec-repo.}
      end

      def initialize(argv)
        super unless argv.empty?
      end

      def master_repo_url
        'git://github.com/alloy/cocoa-pod-specs.git'
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
