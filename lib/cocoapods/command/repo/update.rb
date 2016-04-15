module Pod
  class Command
    class Repo < Command
      class Update < Repo
        self.summary = 'Update a spec repo'

        self.description = <<-DESC
          Updates the local clone of the spec-repo `NAME`. If `NAME` is omitted
          this will update all spec-repos in `~/.cocoapods/repos`.
        DESC

        self.arguments = [
          CLAide::Argument.new('NAME', false),
        ]

        def initialize(argv)
          @name = argv.shift_argument
          super
        end

        def run
          show_output = !config.silent?
          config.sources_manager.update(@name, show_output)
        end
      end
    end
  end
end
