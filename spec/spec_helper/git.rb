require 'spec_helper/temporary_directory'
require 'executioner'

module SpecHelper
  def self.tmp_repos_path
    Git.tmp_repos_path
  end

  module Git
    def tmp_repos_path
      SpecHelper.temporary_directory + 'cocoa-pods'
    end
    module_function :tmp_repos_path

    def tmp_master_repo_path
      tmp_repos_path + 'master'
    end

    include Executioner
    executable :git

    alias_method :git_super, :git
    def git(repo, command)
      Dir.chdir(tmp_repos_path + repo) do
        if output = git_super(command)
          output.strip
        end
      end
    end

    def git_config(repo, attr)
      git repo, "config --get #{attr}"
    end

    def command(*argv)
      command = Pod::Command.parse(*argv)
      command.run
      command
    end

    def add_repo(name, from)
      command('repo', 'add', name, from)
    end

    def make_change(repo, name)
      (repo.dir + 'README').open('w') { |f| f << 'Added!' }
      git(name, 'add README')
      git(name, 'commit -m "changed"')
    end
  end
end
