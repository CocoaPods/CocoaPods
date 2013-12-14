module Pod
  class Command
    class Lib < Command
      self.abstract_command = true
      self.summary = 'Develop pods'

      #-----------------------------------------------------------------------#

      class Create < Lib
        self.summary = 'Creates a new Pod'

        self.description = <<-DESC
          Creates a new Pod with the given name from the template in the working directory.
        DESC

        self.arguments = '[NAME]'

        def initialize(argv)
          @name = argv.shift_argument
          super
        end

        def validate!
          super
          help! "A name for the Pod is required." unless @name
          help! "The Pod name cannot contain spaces." if @name.match(/\s/)
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
        executable :ruby

        TEMPLATE_REPO = "https://github.com/CocoaPods/pod-template.git"
        TEMPLATE_INFO_URL = "https://github.com/CocoaPods/pod-template"
        CREATE_NEW_POD_INFO_URL = "http://guides.cocoapods.org/making/making-a-cocoapod"

        # Clones the template from the remote in the working directory using
        # the name of the Pod.
        #
        # @return [void]
        #
        def clone_template
          UI.section("Creating `#{@name}` Pod") do
            git!"clone '#{TEMPLATE_REPO}' #{@name}"
          end
        end

        # Runs the template configuration utilities.
        #
        # @return [void]
        #
        def configure_template
          UI.section("Configuring template") do
            Dir.chdir(@name) do
              ruby! "_CONFIGURE.rb #{@name}"
            end
          end
        end

        # Runs the template configuration utilities.
        #
        # @return [void]
        #
        def print_info
          UI.puts "\nTo learn more about the template see `#{TEMPLATE_INFO_URL}`."
          UI.puts "To learn more about creating a new pod, see `#{CREATE_NEW_POD_INFO_URL}`."
        end

      end

      #-----------------------------------------------------------------------#

      class Lint < Lib
        self.summary = 'Validates a Pod'

        self.description = <<-DESC
          Validates the Pod using the files in the working directory.
        DESC

        def self.options
          [ ["--quick",       "Lint skips checks that would require to download and build the spec"],
            ["--only-errors", "Lint validates even if warnings are present"],
            ["--subspec=NAME","Lint validates only the given subspec"],
            ["--no-subspecs", "Lint skips validation of subspecs"],
            ["--no-clean",    "Lint leaves the build directory intact for inspection"] ].concat(super)
        end

        def initialize(argv)
          @quick        = argv.flag?('quick')
          @only_errors  = argv.flag?('only-errors')
          @clean        = argv.flag?('clean', true)
          @subspecs     = argv.flag?('subspecs', true)
          @only_subspec = argv.option('subspec')
          @podspecs_paths = argv.arguments!
          super
        end

        def validate!
          super
        end

        def run
          UI.puts
          podspecs_to_lint.each do |podspec|

            validator             = Validator.new(podspec)
            validator.local       = true
            validator.quick       = @quick
            validator.no_clean    = !@clean
            validator.only_errors = @only_errors
            validator.no_subspecs = !@subspecs || @only_subspec
            validator.only_subspec = @only_subspec
            validator.validate

            unless @clean
              UI.puts "Pods project available at `#{validator.validation_dir}/Pods/Pods.xcodeproj` for inspection."
              UI.puts
            end
            if validator.validated?
              UI.puts "#{validator.spec.name} passed validation.".green
            else
              message = "#{validator.spec.name} did not pass validation."
              if @clean
                message << "\nYou can use the `--no-clean` option to inspect " \
                  "any issue."
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
          if !@podspecs_paths.empty? then
            Array(@podspecs_paths)
          else 
            podspecs = Pathname.glob(Pathname.pwd + '*.podspec{.yaml,}')
            raise Informative, "Unable to find a podspec in the working directory" if podspecs.count.zero?
            podspecs
          end
        end

      end

      #-----------------------------------------------------------------------#

    end
  end
end
