module Pod
  class Command
    class Spec < Command
      class Lint < Spec
        self.summary = 'Validates a spec file.'

        self.description = <<-DESC
          Validates `NAME.podspec`. If a `DIRECTORY` is provided, it validates
          the podspec files found, including subfolders. In case
          the argument is omitted, it defaults to the current working dir.
        DESC

        self.arguments = [
          CLAide::Argument.new(%w(NAME.podspec DIRECTORY http://PATH/NAME.podspec), false, true),
        ]

        def self.options
          [['--quick', 'Lint skips checks that would require to download and build the spec'],
           ['--allow-warnings', 'Lint validates even if warnings are present'],
           ['--subspec=NAME', 'Lint validates only the given subspec'],
           ['--no-subspecs', 'Lint skips validation of subspecs'],
           ['--no-clean', 'Lint leaves the build directory intact for inspection'],
           ['--use-frameworks', 'Lint uses frameworks to install the spec'],
           ['--sources=https://github.com/artsy/Specs', 'The sources from which to pull dependant pods ' \
            '(defaults to https://github.com/CocoaPods/Specs.git). '\
            'Multiple sources must be comma-delimited.']].concat(super)
        end

        def initialize(argv)
          @quick           = argv.flag?('quick')
          @allow_warnings  = argv.flag?('allow-warnings')
          @clean           = argv.flag?('clean', true)
          @subspecs        = argv.flag?('subspecs', true)
          @only_subspec    = argv.option('subspec')
          @use_frameworks  = argv.flag?('use-frameworks')
          @source_urls     = argv.option('sources', 'https://github.com/CocoaPods/Specs.git').split(',')
          @podspecs_paths = argv.arguments!
          super
        end

        def run
          UI.puts
          invalid_count = 0
          podspecs_to_lint.each do |podspec|
            validator                = Validator.new(podspec, @source_urls)
            validator.quick          = @quick
            validator.no_clean       = !@clean
            validator.allow_warnings = @allow_warnings
            validator.no_subspecs    = !@subspecs || @only_subspec
            validator.only_subspec   = @only_subspec
            validator.use_frameworks = @use_frameworks
            validator.validate
            invalid_count += 1 unless validator.validated?

            unless @clean
              UI.puts "Pods project available at `#{validator.validation_dir}/Pods/Pods.xcodeproj` for inspection."
              UI.puts
            end
          end

          count = podspecs_to_lint.count
          UI.puts "Analyzed #{count} #{'podspec'.pluralize(count)}.\n\n"
          if invalid_count == 0
            lint_passed_message = count == 1 ? "#{podspecs_to_lint.first.basename} passed validation." : 'All the specs passed validation.'
            UI.puts lint_passed_message.green << "\n\n"
          else
            raise Informative, count == 1 ? 'The spec did not pass validation.' : "#{invalid_count} out of #{count} specs failed validation."
          end
          podspecs_tmp_dir.rmtree if podspecs_tmp_dir.exist?
        end

        private

        def podspecs_to_lint
          @podspecs_to_lint ||= begin
            files = []
            @podspecs_paths << '.' if @podspecs_paths.empty?
            @podspecs_paths.each do |path|
              if path =~ %r{https?://}
                require 'open-uri'
                output_path = podspecs_tmp_dir + File.basename(path)
                output_path.dirname.mkpath
                open(path) do |io|
                  output_path.open('w') { |f| f << io.read }
                end
                files << output_path
              elsif (pathname = Pathname.new(path)).directory?
                files += Pathname.glob(pathname + '**/*.podspec{.json,}')
                raise Informative, 'No specs found in the current directory.' if files.empty?
              else
                files << (pathname = Pathname.new(path))
                raise Informative, "Unable to find a spec named `#{path}'." unless pathname.exist? && path.include?('.podspec')
              end
            end
            files
          end
        end

        def podspecs_tmp_dir
          Pathname.new(Dir.tmpdir) + '/CocoaPods/Lint_podspec'
        end
      end
    end
  end
end
