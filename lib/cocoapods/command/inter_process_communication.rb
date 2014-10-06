module Pod
  class Command
    class IPC < Command
      self.abstract_command = true
      self.summary = 'Inter-process communication'

      def output_pipe
        STDOUT
      end

      #-----------------------------------------------------------------------#

      class Spec < IPC
        self.summary = 'Converts a podspec to JSON.'
        self.description = 'Converts a podspec to JSON and prints it to STDOUT.'
        self.arguments = [
          CLAide::Argument.new('PATH', true),
        ]

        def initialize(argv)
          @path = argv.shift_argument
          super
        end

        def validate!
          super
          help! 'A specification path is required.' unless @path
        end

        def run
          require 'json'
          spec = Specification.from_file(@path)
          output_pipe.puts(JSON.pretty_generate(spec))
        end
      end

      #-----------------------------------------------------------------------#

      class Podfile < IPC
        self.summary = 'Converts a Podfile to YAML.'
        self.description = 'Converts a Podfile to YAML and prints it to STDOUT.'
        self.arguments = [
          CLAide::Argument.new('PATH', true),
        ]

        def initialize(argv)
          @path = argv.shift_argument
          super
        end

        def validate!
          super
          help! 'A Podfile path is required.' unless @path
        end

        def run
          podfile = Pod::Podfile.from_file(@path)
          output_pipe.puts podfile.to_yaml
        end
      end

      #-----------------------------------------------------------------------#

      class List < IPC
        self.summary = 'Lists the specifications known to CocoaPods.'
        self.description = <<-DESC
          Prints to STDOUT a YAML dictionary where the keys are the name of the
          specifications and each corresponding value is a dictionary with
          the following keys:

          - defined_in_file
          - version
          - authors
          - summary
          - description
          - platforms
        DESC

        def run
          sets = SourcesManager.aggregate.all_sets
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
          output_pipe.puts result.to_yaml
        end
      end

      #-----------------------------------------------------------------------#

      class UpdateSearchIndex < IPC
        self.summary = 'Updates the search index.'
        self.description = <<-DESC
          Updates the search index and prints its path to standard output.
          The search index is a YAML encoded dictionary where the keys
          are the names of the Pods and the values are a dictionary containing
          the following information:

          - version
          - summary
          - description
          - authors
        DESC

        def run
          SourcesManager.updated_search_index
          output_pipe.puts(SourcesManager.search_index_path)
        end
      end

      #-----------------------------------------------------------------------#

      class Repl < IPC
        END_OF_OUTPUT_SIGNAL = "\n\r"

        self.summary = 'The repl listens to commands on standard input.'
        self.description = <<-DESC
         The repl listens to commands on standard input and prints their
         result to standard output.

         It accepts all the other ipc subcommands. The repl will signal the
         end of output with the the ASCII CR+LF `\\n\\r`.
        DESC

        def run
          print_version
          signal_end_of_output
          listen
        end

        def print_version
          output_pipe.puts "version: '#{Pod::VERSION}'"
        end

        def signal_end_of_output
          output_pipe.puts(END_OF_OUTPUT_SIGNAL)
          STDOUT.flush
        end

        def listen
          while repl_command = STDIN.gets
            execute_repl_command(repl_command)
          end
        end

        def execute_repl_command(repl_command)
          if (repl_command != "\n")
            repl_commands = repl_command.split
            subcommand = repl_commands.shift.capitalize
            arguments = repl_commands
            subcommand_class = Pod::Command::IPC.const_get(subcommand)
            subcommand_class.new(CLAide::ARGV.new(arguments)).run
            signal_end_of_output
          end
        end
      end

      #-----------------------------------------------------------------------#
    end
  end
end
