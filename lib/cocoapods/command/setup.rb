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
        [["--push", "Use this option to enable push access once granted"]].concat(super)
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

      def add_master_repo
        @command ||= Repo.new(ARGV.new(['add', 'master', url, '0.6'])).run
      end

      def update_master_repo
        Repo.new(ARGV.new(['update', 'master'])).run
      end

      #TODO: remove after rc
      def set_master_repo_branch
        Dir.chdir(dir) do
          git("checkout 0.6")
        end
      end

      def run_if_needed
        run unless dir.exist? && Repo.compatible?('master')
      end

      def run
        print_title "Setting up CocoaPods master repo"
        if dir.exist?
          set_master_repo_url
          set_master_repo_branch
          update_master_repo
        else
          add_master_repo
        end
        # Mainly so the specs run with submodule repos
        if (dir + '.git/hooks').exist?
          hook = dir + '.git/hooks/pre-commit'
          hook.open('w') { |f| f << "#!/bin/sh\nrake lint" }
          `chmod +x '#{hook}'`
        end
        print_subtitle "Setup completed (#{push? ? "push" : "read-only"} access)"
      end
    end
  end
end
