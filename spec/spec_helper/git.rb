require 'spec_helper/temporary_directory'
require 'executioner'

module SpecHelper
  def self.tmp_repos_path
    Git.tmp_repos_path
  end

  module Git
    def tmp_repos_path
      File.join(SpecHelper.temporary_directory, 'cocoa-pods')
    end
    module_function :tmp_repos_path

    def tmp_master_repo_path
      File.join(tmp_repos_path, 'master')
    end

    include Executioner
    executable :git

    alias_method :git_super, :git
    def git(command)
      Dir.chdir(tmp_master_repo_path) { git_super(command).strip }
    end

    def git_config(attr)
      git "config --get #{attr}"
    end
  end
end
