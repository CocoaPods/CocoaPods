module Pod
  class Command
    class Help < Command
      self.summary = 'Show help for the given command.'
      self.arguments = [
        CLAide::Argument.new('COMMAND', false),
      ]

      def initialize(argv)
        @help_command = Pod::Command.parse(argv)
        super
      end

      def run
        help_command.help!
      end

      private

      attr_reader :help_command
    end
  end
end
