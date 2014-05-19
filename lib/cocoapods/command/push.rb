module Pod
  class Command
    class Push < Command
      self.summary = 'Temporary placeholder for the `pod repo push` command'


      def initialize(argv)
        @push_command = Repo::Push.new(argv)
        super
      end

      def validate!
        UI.puts '[!] The `pod push` command has been moved to `pod repo push`.'.ansi.yellow
        @push_command.validate!
      end

      def run
        @push_command.run
      end
    end
  end
end
