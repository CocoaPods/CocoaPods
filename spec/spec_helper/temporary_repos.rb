require 'spec_helper/temporary_directory'

module SpecHelper
  def self.tmp_repos_path
    TemporaryRepos.tmp_repos_path
  end

  module TemporaryRepos
    extend Pod::Executable
    executable :git

    def tmp_repos_path
      SpecHelper.temporary_directory + 'cocoapods'
    end
    module_function :tmp_repos_path

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

    def add_repo(name, from)
      command = command('repo', 'add', name, from)
      command.run
      Dir.chdir(command.dir) { `git checkout -b test >/dev/null 2>&1` }
      command
    end

    def make_change(repo, name)
      (repo.dir + 'README').open('w') { |f| f << 'Added!' }
      git(name, 'add README')
      git(name, 'commit -m "changed"')
    end

    def self.extended(base)
      base.before do
        tmp_repos_path.mkpath
      end
    end
  end
end

