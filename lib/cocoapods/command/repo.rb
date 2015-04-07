require 'fileutils'
require 'cocoapods/command/repo/add'
require 'cocoapods/command/repo/lint'
require 'cocoapods/command/repo/list'
require 'cocoapods/command/repo/push'
require 'cocoapods/command/repo/remove'
require 'cocoapods/command/repo/update'

module Pod
  class Command
    class Repo < Command
      self.abstract_command = true

      # @todo should not show a usage banner!
      #
      self.summary = 'Manage spec-repositories'
      self.default_subcommand = 'list'

      #-----------------------------------------------------------------------#

      extend Executable
      executable :git

      def dir
        config.repos_dir + @name
      end

      # Returns the branch name (i.e. master).
      #
      # @return [String] The name of the current branch.
      #
      def branch_name
        `git name-rev --name-only HEAD`.strip
      end

      # Returns the branch remote name (i.e. origin).
      #
      # @param  [#to_s] branch_name
      #         The branch name to look for the remote name.
      #
      # @return [String] The given branch's remote name.
      #
      def branch_remote_name(branch_name)
        `git config branch.#{branch_name}.remote`.strip
      end
    end
  end
end
