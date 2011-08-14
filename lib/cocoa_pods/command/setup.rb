require 'fileutils'
require 'executioner'

module Pod
  class Command
    class Setup < Command
      include Executioner
      executable :git

      def repos_dir
        File.expand_path('~/.cocoa-pods')
      end

      def master_repo_dir
        File.join(repos_dir, 'master')
      end

      def master_repo_url
        'git://github.com/alloy/cocoa-pod-specs.git'
      end

      def run
        FileUtils.mkdir_p(repos_dir)
        Dir.chdir(repos_dir) { git("clone #{master_repo_url} master") }
      end
    end
  end
end
