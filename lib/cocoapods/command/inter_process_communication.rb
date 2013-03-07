module Pod
  class Command
    class IPC < Command

      self.abstract_command = true
      self.summary = 'Inter-process communication'

      #-----------------------------------------------------------------------#

      class Spec < IPC

        self.summary = 'Converts a podspec to YAML.'
        self.description = 'Converts a podspec to YAML and prints it to STDOUT.'
        self.arguments = 'PATH'

        def initialize(argv)
          @path = argv.shift_argument
          super
        end

        def validate!
          super
          help! "A specification path is required." unless @path
        end

        def run
          spec = Specification.from_file(@path)
          UI.puts spec.to_yaml
        end

      end

      #-----------------------------------------------------------------------#

      class Podfile < IPC

        self.summary = 'Converts a Podfile to YAML.'
        self.description = 'Converts a Podfile to YAML and prints it to STDOUT.'
        self.arguments = 'PATH'

        def initialize(argv)
          @path = argv.shift_argument
          super
        end

        def validate!
          super
          help! "A Podfile path is required." unless @path
        end

        def run
          podfile = Pod::Podfile.from_file(@path)
          UI.puts podfile.to_yaml
        end

      end

      #-----------------------------------------------------------------------#

      class List < IPC

        self.summary = 'Lists the specifications know to CocoaPods.'
        self.description = <<-DESC
          Prints to STDOUT a YAML dictionary where the keys are the name of the
          specifications and the values are a dictionary with the following
          keys.

          - defined_in_file
          - version
          - authors
          - summary
          - description
          - platforms
        DESC

        def run
          sets = SourcesManager.all_sets
          result = {}
          sets.each do |set|
            begin
              spec = set.specification
              result[spec.name] = {
                'authors' => spec.authors.keys,
                'summary' => spec.summary,
                'description' => spec.description,
                'platforms' => spec.available_platforms.map { |p| p.name.to_s },
              }
            rescue DSLError
              next
            end
          end
          UI.puts result.to_yaml
        end

      end

      #-----------------------------------------------------------------------#

      class Repl < IPC

        LISTENING_STRING = '>>> @LISTENING <<<'

        self.summary = 'The repl listens to commands on standard input.'
        self.description = <<-DESC
         The repl listens to commands on standard input and prints their
         result to standard output.

         It accepts all the other ipc subcommands. The repl will signal when
         it is ready to receive a new command with the `#{LISTENING_STRING}`
         string.
        DESC

        def run
          salute
          listen
        end

        def salute
          UI.puts "version: '#{Pod::VERSION}'"
        end

        def listen
          signal_ready
          while repl_command = STDIN.gets
            execute_repl_command(repl_command)
          end
        end

        def signal_ready
          UI.puts LISTENING_STRING
          STDOUT.flush
        end

        def execute_repl_command(repl_command)
          if (repl_command != "\n")
            repl_commands = repl_command.split
            subcommand = repl_commands.shift.capitalize
            arguments = repl_commands
            subcommand_class = Pod::Command::IPC.const_get(subcommand)
            subcommand_class.new(CLAide::ARGV.new(arguments)).run
            signal_ready
          end
        end

      end

      #-----------------------------------------------------------------------#

    end
  end
end
