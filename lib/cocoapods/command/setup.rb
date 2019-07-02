require 'fileutils'

module Pod
  class Command
    class Setup < Command
      self.summary = 'Setup the CocoaPods environment'

      self.description = <<-DESC
        Creates a directory at `#{Config.instance.repos_dir}` which will hold your spec-repos.
        This is where it will create a clone of the public `master` spec-repo from:

            https://github.com/CocoaPods/Specs

        If the clone already exists, it will ensure that it is up-to-date.
      DESC

      def run
        UI.puts 'Setup was deprecated in 1.8.0, as it is no longer necessary!'.green
      end
    end
  end
end
