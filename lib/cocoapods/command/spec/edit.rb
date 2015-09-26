module Pod
  class Command
    class Spec < Command
      class Edit < Spec
        self.summary = 'Edit a spec file.'

        self.description = <<-DESC
          Opens the podspec matching `QUERY` to be edited.
        DESC

        self.arguments = [
          CLAide::Argument.new('QUERY', false),
        ]

        def self.options
          [
            ['--regex', 'Interpret the `QUERY` as a regular expression'],
            ['--show-all', 'Pick from all versions of the given podspec'],
          ].concat(super)
        end

        def initialize(argv)
          @use_regex = argv.flag?('regex')
          @show_all = argv.flag?('show-all')
          @query = argv.shift_argument
          @query = @query.gsub('.podspec', '') unless @query.nil?
          super
        end

        def validate!
          super
          help! 'A podspec name is required.' unless @query
          validate_regex!(@query) if @use_regex
        end

        def run
          query = @use_regex ? @query : Regexp.escape(@query)
          if @show_all
            specs = get_path_of_spec(query, @show_all).split(/\n/)
            message = "Which spec would you like to edit [1-#{specs.count}]? "
            index = UI.choose_from_array(specs, message)
            filepath = specs[index]
          else
            filepath = get_path_of_spec(query)
          end

          exec_editor(filepath.to_s) if File.exist? filepath
          raise Informative, "#{filepath} doesn't exist."
        end

        # Looks up an executable in the search paths
        #
        # @note
        # Thank you homebrew
        #
        # @param [String] cmd
        #        the executable to look up
        #
        def which(cmd)
          dir = ENV['PATH'].split(':').find { |p| File.executable? File.join(p, cmd) }
          Pathname.new(File.join(dir, cmd)) unless dir.nil?
        end

        def which_editor
          editor = ENV['EDITOR']
          # If an editor wasn't set, try to pick a sane default
          return editor unless editor.nil?

          # Find Sublime Text 2
          return 'subl' if which 'subl'
          # Find Textmate
          return 'mate' if which 'mate'
          # Find # BBEdit / TextWrangler
          return 'edit' if which 'edit'
          # Default to vim
          return 'vim' if which 'vim'

          raise Informative, "Failed to open editor. Set your 'EDITOR' environment variable."
        end

        def exec_editor(*args)
          return if args.to_s.empty?
          safe_exec(which_editor, *args)
        end

        def safe_exec(cmd, *args)
          # This buys us proper argument quoting and evaluation
          # of environment variables in the cmd parameter.
          exec('/bin/sh', '-i', '-c', cmd + ' "$@"', '--', *args)
        end
      end
    end
  end
end
