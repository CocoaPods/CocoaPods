module Pod
  class Command
    class Repo < Command
      class Add < Repo
        self.summary = 'Add a spec repo.'

        self.description = <<-DESC
          Clones `URL` in the local spec-repos directory at `~/.cocoapods/repos/`. The
          remote can later be referred to by `NAME`.
        DESC

        self.arguments = [
          CLAide::Argument.new('NAME',   true),
          CLAide::Argument.new('URL',    true),
          CLAide::Argument.new('BRANCH', false),
        ]

        def self.options
          [
            ['--shallow', 'Create a shallow clone (fast clone, but no push capabilities)'],
          ].concat(super)
        end

        def initialize(argv)
          @shallow = argv.flag?('shallow', false)
          @name, @url, @branch = argv.shift_argument, argv.shift_argument, argv.shift_argument
          super
        end

        def validate!
          super
          unless @name && @url
            help! 'Adding a repo needs a `NAME` and a `URL`.'
          end
        end

        def run
          prefix = @shallow ? 'Creating shallow clone of' : 'Cloning'
          UI.section("#{prefix} spec repo `#{@name}` from `#{@url}`#{" (branch `#{@branch}`)" if @branch}") do
            config.repos_dir.mkpath
            Dir.chdir(config.repos_dir) do
              command = ['clone', @url, @name]
              command << '--depth=1' if @shallow
              git!(command)
            end
            Dir.chdir(dir) { git!('checkout', @branch) } if @branch
            SourcesManager.check_version_information(dir)
          end
        end
      end
    end
  end
end
