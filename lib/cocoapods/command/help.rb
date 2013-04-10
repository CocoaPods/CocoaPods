module Pod
  class Command
    class Help < Command
      self.summary = 'Show help for the given command.'
      self.arguments = '[COMMAND]'

      def initialize(argv)
        @help_command = Pod::Command.parse(argv) unless argv.empty?
        super
      end

      def run
        help_command.help!
      end

      private

      def help_command
        @help_command || self
      end
    end
  end
end
