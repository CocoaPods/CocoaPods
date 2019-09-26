require 'fileutils'

module Pod
  class Command
    class Setup < Command
      self.summary = 'Setup the CocoaPods environment'

      self.description = <<-DESC
        Setup the CocoaPods environment
      DESC

      def run
        # Right now, no setup is needed
        UI.puts 'Setup completed'.green
      end
    end
  end
end
