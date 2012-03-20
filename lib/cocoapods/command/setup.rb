module Pod
  class Command
    class Setup < Command
      def self.banner
%{Setup CocoaPods environment:

    $ pod setup

      Creates a directory at `~/.cocoapods' which will hold your spec-repos.
      This is where it will create a clone of the public `master' spec-repo from:

          https://github.com/CocoaPods/Specs

      If the clone already exists, it will ensure that it is up-to-date.}
      end

      def self.options
        "    --push      Use this option to enable push access once granted\n" +
        super
      end

      def initialize(argv)
        @push_access  = argv.option('--push') || already_push?
        puts "Setup with push access" if @push_access && !config.silent
        super unless argv.empty?
      end

      def already_push?
        if master_repo_exists?
          read_master_repo_remote_command.run
          read_master_repo_remote_command.output.chomp == master_repo_url_with_push
        else
          false
        end
      end

      def master_repo_exists?
        (config.repos_dir + 'master').exist?
      end

      def master_repo_url
        'git://github.com/CocoaPods/Specs.git'
      end

      def master_repo_url_with_push
        'git@github.com:CocoaPods/Specs.git'
      end

      def repo_url
        @push_access ? master_repo_url_with_push : master_repo_url
      end

      def add_master_repo_command
        @command ||= Repo.new(ARGV.new(['add', 'master', repo_url]))
      end

      def read_master_repo_remote_command
        @read_command ||= Repo.new(ARGV.new(['read-url', 'master']))
      end

      def update_master_repo_remote_command
        Repo.new(ARGV.new(['set-url', 'master', repo_url]))
      end

      def update_master_repo_command
        Repo.new(ARGV.new(['update', 'master']))
      end

      def run
        if master_repo_exists?
          update_master_repo_remote_command.run
          update_master_repo_command.run
        else
          add_master_repo_command.run
        end
        hook = config.repos_dir + 'master/.git/hooks/pre-commit'
        hook.open('w') { |f| f << "#!/bin/sh\nrake lint" }
        `chmod +x '#{hook}'`
      end
    end
  end
end
