require 'fileutils'

module Pod
  class Command
    class Repo < Command
      self.abstract_command = true

      # TODO should not show a usage banner!
      self.summary = 'Manage spec-repositories'

      class Add < Repo
        self.summary = 'Add a spec repo.'

        self.description = <<-DESC
          Clones `URL' in the local spec-repos directory at `~/.cocoapods'. The
          remote can later be referred to by `NAME'.
        DESC

        self.arguments = 'NAME URL [BRANCH]'

        def initialize(argv)
          @name, @url, @branch = argv.shift_argument, argv.shift_argument, argv.shift_argument
          super
        end

        def validate!
          super
          unless @name && @url
            help! "Adding a repo needs a `NAME' and a `URL."
          end
        end

        def run
          UI.section("Cloning spec repo `#{@name}' from `#{@url}'#{" (branch `#{@branch}')" if @branch}") do
            config.repos_dir.mkpath
            Dir.chdir(config.repos_dir) { git!("clone '#{@url}' #{@name}") }
            Dir.chdir(dir) { git!("checkout #{@branch}") } if @branch
            check_versions(dir)
          end
        end
      end

      class Update < Repo
        self.summary = 'Update a spec repo.'

        self.description = <<-DESC
          Updates the local clone of the spec-repo `NAME'. If `NAME' is omitted
          this will update all spec-repos in `~/.cocoapods'.
        DESC

        self.arguments = '[NAME]'

        def initialize(argv)
          @name = argv.shift_argument
          super
        end

        def run
          dirs = @name ? [dir] : config.repos_dir.children.select {|c| c.directory?}
          dirs.each do |dir|
            UI.section "Updating spec repo `#{dir.basename}'" do
              Dir.chdir(dir) do
                `git rev-parse  >/dev/null 2>&1`
                if $?.exitstatus.zero?
                  git!("pull")
                else
                  UI.message "Not a git repository"
                end
              end
            end
            check_versions(dir)
          end
        end
      end

      class Lint < Repo
        self.summary = 'Validates all specs in a repo.'

        self.description = <<-DESC
          Lints the spec-repo `NAME'. If a directory is provided it is assumed
          to be the root of a repo. Finally, if `NAME' is not provided this
          will lint all the spec-repos known to CocoaPods.
        DESC

        self.arguments = '[ NAME | DIRECTORY ]'

        def self.options
          [["--only-errors", "Lint presents only the errors"]].concat(super)
        end

        def initialize(argv)
          @name = argv.shift_argument
          @only_errors = argv.flag?('only-errors')
          super
        end

        def run
          if @name
            dirs = File.exists?(@name) ? [ Pathname.new(@name) ] : [ dir ]
          else
            dirs = config.repos_dir.children.select {|c| c.directory?}
          end
          dirs.each do |dir|
            check_versions(dir)
            UI.puts "\nLinting spec repo `#{dir.realpath.basename}'\n".yellow
            podspecs = Pathname.glob( dir + '**/*.podspec')
            invalid_count = 0

            podspecs.each do |podspec|
              linter = Linter.new(podspec)
              linter.quick     = true
              linter.repo_path = dir

              linter.lint

              case linter.result_type
              when :error
                invalid_count += 1
                color = :red
                should_display = true
              when :warning
                color = :yellow
                should_display = !@only_errors
              end

              if should_display
                UI.puts " -> ".send(color) << linter.spec_name
                print_messages('ERROR', linter.errors)
                unless @only_errors
                  print_messages('WARN',  linter.warnings)
                  print_messages('NOTE',  linter.notes)
                end
                UI.puts unless config.silent?
              end
            end
            UI.puts "Analyzed #{podspecs.count} podspecs files.\n\n" unless config.silent?

            if invalid_count == 0
              UI.puts "All the specs passed validation.".green << "\n\n" unless config.silent?
            else
              raise Informative, "#{invalid_count} podspecs failed validation."
            end
          end
        end
      end

      extend Executable
      executable :git

      # TODO some of the following methods can probably move to one of the subclasses.

      protected

      def dir
        config.repos_dir + @name
      end

      def print_messages(type, messages)
        return if config.silent?
        messages.each {|msg| UI.puts "    - #{type.ljust(5)} | #{msg}"}
      end

      def check_versions(dir)
        versions = versions(dir)
        unless is_compatilbe(versions)
          min, max = versions['min'], versions['max']
          version_msg = ( min == max ) ? min : "#{min} - #{max}"
          raise Informative,
          "\n[!] The `#{dir.basename.to_s}' repo requires CocoaPods #{version_msg}\n".red +
          "Update Cocoapods, or checkout the appropriate tag in the repo.\n\n"
        end
        UI.puts "\nCocoapods #{versions['last']} is available.\n".green if has_update(versions) && config.new_version_message?
      end

      def self.compatible?(name)
        dir = Config.instance.repos_dir + name
        versions = versions(dir)
        is_compatilbe(versions)
      end

      private

      def versions(dir)
        self.class.versions(dir)
      end

      def self.versions(dir)
        require 'yaml'
        yaml_file  = dir + 'CocoaPods-version.yml'
        yaml_file.exist? ? YAML.load_file(yaml_file) : {}
      end

      def is_compatilbe(versions)
        self.class.is_compatilbe(versions)
      end

      def self.is_compatilbe(versions)
        min, max = versions['min'], versions['max']
        supports_min = !min || bin_version >= Gem::Version.new(min)
        supports_max = !max || bin_version <= Gem::Version.new(max)
        supports_min && supports_max
      end

      def has_update(versions)
        self.class.has_update(versions)
      end

      def self.has_update(versions)
        last = versions['last']
        last && Gem::Version.new(last) > bin_version
      end

      def self.bin_version
        Gem::Version.new(VERSION)
      end

    end
  end
end

