module Pod
  class Command
    class Help < Command
      self.summary = 'Show help for the given command'
      self.arguments = '[COMMAND]'

      def self.parse(argv)
        command_needs_help = [argv.shift_argument, '--help']
        argv.empty? ? super : Pod::Command.parse(command_needs_help)
      end

      def run
        help!
      end
    end
  end
end