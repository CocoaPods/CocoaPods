require 'cocoa_pods/command/repo'

module Pod
  class Command
    class Setup < Command
      def master_repo_url
        'git://github.com/alloy/cocoa-pod-specs.git'
      end

      def add_master_repo_command
        @command ||= Repo.new('add', 'master', master_repo_url)
      end

      def run
        add_master_repo_command.run
      end
    end
  end
end
