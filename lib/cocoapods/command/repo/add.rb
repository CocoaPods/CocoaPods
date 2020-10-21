module Pod
  class Command
    class Repo < Command
      class Add < Repo
        self.summary = 'Add a spec repo'

        self.description = <<-DESC
          Clones `URL` in the local spec-repos directory at `#{Config.instance.repos_dir}`. The
          remote can later be referred to by `NAME`.
        DESC

        self.arguments = [
          CLAide::Argument.new('NAME',   true),
          CLAide::Argument.new('URL',    true),
          CLAide::Argument.new('BRANCH', false),
        ]

        def self.options
          [
            ['--progress', 'Show the progress of cloning the spec repository'],
            ['--sparse', 'Add the spec repository using sparse checkout and partial clone, good for huge repos'],
          ].concat(super)
        end

        def initialize(argv)
          @name = argv.shift_argument
          @url = argv.shift_argument
          @branch = argv.shift_argument
          @progress = argv.flag?('progress')
          @sparse = argv.flag?('sparse')
          super
        end

        def validate!
          super
          unless @name && @url
            help! 'Adding a repo needs a `NAME` and a `URL`.'
          end
          if @name == 'trunk'
            raise Informative,
                  "Repo name `trunk` is reserved for CocoaPods' main spec repo accessed via CDN."
          end
        end

        def run
          section = "Cloning spec repo `#{@name}` from `#{@url}`"
          section << " (branch `#{@branch}`)" if @branch
          UI.section(section) do
            create_repos_dir
            clone_repo
            initialize_sparse_checkout if @sparse
            checkout_branch
            config.sources_manager.sources([dir.basename.to_s]).each(&:verify_compatibility!)
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
          changes = if @progress
                      { :verbose => true }
                    else
                      {}
                    end

          config.with_changes(changes) do
            Dir.chdir(config.repos_dir) do
              command = ['clone', @url]
              command << '--progress' if @progress
              command << %w[--filter=blob:none --no-checkout --depth 1] if @sparse
              command << '--' << @name
              git!(command)
            end
          end
        end

        # Checks out the branch of the git spec-repo if provided.
        #
        # @return [void]
        #
        def checkout_branch
          Dir.chdir(dir) { git!('checkout', @branch) } if @branch
        end

        # Initialize a sparse checkout in the git spec-repo.
        #
        # @return [void]
        #
        def initialize_sparse_checkout
          Dir.chdir(dir) do
            git!(%w[config core.sparseCheckout true])
            git!(%w[config core.sparseCheckoutCone true])
            File.open('.git/info/sparse-checkout', 'w') do |sparse|
              sparse.puts '/*'
              sparse.puts '!/*/'
              sparse.puts '/Specs/*'
              sparse.puts '!/Specs/*/'
            end
            command = ['checkout']
            command << '--progress' if @progress
            git!(command)
          end
        end
      end
    end
  end
end
