module Pod
  class Command
    class Setup < Command
      def self.banner
%{Setup CocoaPods environment:

    $ pod setup

      Creates a directory at '~/.cocoapods' which will hold your spec-repos.
      This is where it will create a clone of the public 'master' spec-repo from:

          https://github.com/CocoaPods/Specs

      If the clone already exists, it will ensure that it is up-to-date.}
      end

      def self.options
        "    --push      Use this option to enable push access once granted\n" +
        super
      end

      extend Executable
      executable :git

      def initialize(argv)
        @push_option  = argv.option('--push')
        super unless argv.empty?
      end

      def dir
        config.repos_dir + 'master'
      end

      def read_only_url
        'git://github.com/CocoaPods/Specs.git'
      end

      def read_write_url
        'git@github.com:CocoaPods/Specs.git'
      end

      def url
        if push?
          read_write_url
        else
          read_only_url
        end
      end

      def origin_url_read_only?
        read_master_repo_url.chomp == read_only_url
      end

      def origin_url_push?
        read_master_repo_url.chomp == read_write_url
      end

      def push?
       @push_option || (dir.exist? && origin_url_push?)
      end

      def read_master_repo_url
        Dir.chdir(dir) do
          origin_url = git('config --get remote.origin.url')
        end
      end

      def set_master_repo_url
        Dir.chdir(dir) do
          git("remote set-url origin '#{url}'")
        end
      end

      def add_master_repo_command
        @command ||= Repo.new(ARGV.new(['add', 'master', url]))
      end

      def update_master_repo_command
        Repo.new(ARGV.new(['update', 'master']))
      end

      def run_if_needed
        run if !dir.exist?
      end

      def run
        puts "Using push access" if push? && !config.silent
        if dir.exist?
          set_master_repo_url
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
