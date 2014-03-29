module Pod
  class Command
    class Help < Command
      self.summary = 'Show help for the given command.'
      self.arguments = '[COMMAND]'

      def run
        help!
      end
    end
  end
end
