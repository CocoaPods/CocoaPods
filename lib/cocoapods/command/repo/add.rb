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
          @name = argv.shift_argument
          @url = argv.shift_argument
          @branch = argv.shift_argument
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
            create_repos_dir
            clone_repo
            checkout_branch
            SourcesManager.check_version_information(dir)
          end
        end

        private

        # Creates the repos directory specified in the configuration by
        # `config.repos_dir`.
        #
        # @return [void]
        #
        # @raise  If the directory cannot be created due to a system error.
        #
        def create_repos_dir
          config.repos_dir.mkpath
        rescue => e
          raise Informative, "Could not create '#{config.repos_dir}', the CocoaPods repo cache directory.\n" \
            "#{e.class.name}: #{e.message}"
        end

        # Clones the git spec-repo according to parameters passed to the
        # command.
        #
        # @return [void]
        #
        def clone_repo
          Dir.chdir(config.repos_dir) do
            command = ['clone', @url, @name]
            command << '--depth=1' if @shallow
            git!(command)
          end
        end

        # Checks out the branch of the git spec-repo if provided.
        #
        # @return [void]
        #
        def checkout_branch
          Dir.chdir(dir) { git!('checkout', @branch) } if @branch
        end
      end
    end
  end
end
