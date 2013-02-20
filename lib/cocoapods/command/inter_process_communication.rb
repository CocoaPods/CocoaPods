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
                'defined_in_file' => spec.defined_in_file.to_s,
                'version' => spec.version,
                'authors' => spec.authors,
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

    end
  end
end
