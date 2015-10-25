module Pod
  class Command
    class Lib < Command
      self.abstract_command = true
      self.summary = 'Develop pods'

      #-----------------------------------------------------------------------#

      class Create < Lib
        self.summary = 'Creates a new Pod'

        self.description = <<-DESC
          Creates a scaffold for the development of a new Pod named `NAME`
          according to the CocoaPods best practices.
          If a `TEMPLATE_URL`, pointing to a git repo containing a compatible
          template, is specified, it will be used in place of the default one.
        DESC

        self.arguments = [
          CLAide::Argument.new('NAME', true),
        ]

        def self.options
          [
            ['--template-url=URL', 'The URL of the git repo containing a ' \
                                  'compatible template'],
          ].concat(super)
        end

        def initialize(argv)
          @name = argv.shift_argument
          @template_url = argv.option('template-url', TEMPLATE_REPO)
          super
          @additional_args = argv.remainder!
        end

        def validate!
          super
          help! 'A name for the Pod is required.' unless @name
          help! 'The Pod name cannot contain spaces.' if @name.match(/\s/)
          help! "The Pod name cannot begin with a '.'" if @name[0, 1] == '.'
        end

        def run
          clone_template
          configure_template
          print_info
        end

        private

        #----------------------------------------#

        # !@group Private helpers

        extend Executable
        executable :git

        TEMPLATE_REPO = 'https://github.com/CocoaPods/pod-template.git'
        TEMPLATE_INFO_URL = 'https://github.com/CocoaPods/pod-template'
        CREATE_NEW_POD_INFO_URL = 'http://guides.cocoapods.org/making/making-a-cocoapod'

        # Clones the template from the remote in the working directory using
        # the name of the Pod.
        #
        # @return [void]
        #
        def clone_template
          UI.section("Cloning `#{template_repo_url}` into `#{@name}`.") do
            git! ['clone', template_repo_url, @name]
          end
        end

        # Runs the template configuration utilities.
        #
        # @return [void]
        #
        def configure_template
          UI.section("Configuring #{@name} template.") do
            Dir.chdir(@name) do
              if File.exist?('configure')
                system('./configure', @name, *@additional_args)
              else
                UI.warn 'Template does not have a configure file.'
              end
            end
          end
        end

        # Runs the template configuration utilities.
        #
        # @return [void]
        #
        def print_info
          UI.puts "\nTo learn more about the template see `#{template_repo_url}`."
          UI.puts "To learn more about creating a new pod, see `#{CREATE_NEW_POD_INFO_URL}`."
        end

        # Checks if a template URL is given else returns the TEMPLATE_REPO URL
        #
        # @return String
        #
        def template_repo_url
          @template_url || TEMPLATE_REPO
        end
      end

      #-----------------------------------------------------------------------#

      class Lint < Lib
        self.summary = 'Validates a Pod'

        self.description = <<-DESC
          Validates the Pod using the files in the working directory.
        DESC

        def self.options
          [
            ['--quick', 'Lint skips checks that would require to download and build the spec'],
            ['--allow-warnings', 'Lint validates even if warnings are present'],
            ['--subspec=NAME', 'Lint validates only the given subspec'],
            ['--no-subspecs', 'Lint skips validation of subspecs'],
            ['--no-clean', 'Lint leaves the build directory intact for inspection'],
            ['--fail-fast', 'Lint stops on the first failing platform or subspec'],
            ['--use-libraries', 'Lint uses static libraries to install the spec'],
            ['--sources=https://github.com/artsy/Specs,master', 'The sources from which to pull dependent pods ' \
             '(defaults to https://github.com/CocoaPods/Specs.git). ' \
             'Multiple sources must be comma-delimited.'],
            ['--private', 'Lint skips checks that apply only to public specs'],
          ].concat(super)
        end

        def initialize(argv)
          @quick           = argv.flag?('quick')
          @allow_warnings  = argv.flag?('allow-warnings')
          @clean           = argv.flag?('clean', true)
          @fail_fast       = argv.flag?('fail-fast', false)
          @subspecs        = argv.flag?('subspecs', true)
          @only_subspec    = argv.option('subspec')
          @use_frameworks  = !argv.flag?('use-libraries')
          @source_urls     = argv.option('sources', 'https://github.com/CocoaPods/Specs.git').split(',')
          @private         = argv.flag?('private', false)
          @podspecs_paths  = argv.arguments!
          super
        end

        def validate!
          super
        end

        def run
          UI.puts
          podspecs_to_lint.each do |podspec|
            validator                = Validator.new(podspec, @source_urls)
            validator.local          = true
            validator.quick          = @quick
            validator.no_clean       = !@clean
            validator.fail_fast      = @fail_fast
            validator.allow_warnings = @allow_warnings
            validator.no_subspecs    = !@subspecs || @only_subspec
            validator.only_subspec   = @only_subspec
            validator.use_frameworks = @use_frameworks
            validator.ignore_public_only_results = @private
            validator.validate

            unless @clean
              UI.puts "Pods workspace available at `#{validator.validation_dir}/App.xcworkspace` for inspection."
              UI.puts
            end
            if validator.validated?
              UI.puts "#{validator.spec.name} passed validation.".green
            else
              spec_name = podspec
              spec_name = validator.spec.name if validator.spec
              message = "#{spec_name} did not pass validation, due to #{validator.failure_reason}."

              if @clean
                message << "\nYou can use the `--no-clean` option to inspect " \
                  'any issue.'
              end
              raise Informative, message
            end
          end
        end

        private

        #----------------------------------------#

        # !@group Private helpers

        # @return [Pathname] The path of the podspec found in the current
        #         working directory.
        #
        # @raise  If no podspec is found.
        # @raise  If multiple podspecs are found.
        #
        def podspecs_to_lint
          if !@podspecs_paths.empty?
            Array(@podspecs_paths)
          else
            podspecs = Pathname.glob(Pathname.pwd + '*.podspec{.json,}')
            if podspecs.count.zero?
              raise Informative, 'Unable to find a podspec in the working ' \
                'directory'
            end
            podspecs
          end
        end
      end

      #-----------------------------------------------------------------------#
    end
  end
end
