require 'xcodeproj'
require 'active_support/core_ext/string/strip'

module Pod
  class Command
    class Init < Command
      self.summary = 'Generate a Podfile for the current directory'
      self.description = <<-DESC
        Creates a Podfile for the current directory if none currently exists. If
        an `XCODEPROJ` project file is specified or if there is only a single
        project file in the current directory, targets will be automatically
        generated based on targets defined in the project.

        It is possible to specify a list of dependencies which will be used by
        the template in the `Podfile.default` (normal targets) `Podfile.test`
        (test targets) files which should be stored in the
        `~/.cocoapods/templates` folder.
      DESC
      self.arguments = [
        CLAide::Argument.new('XCODEPROJ', :false),
      ]

      def initialize(argv)
        @podfile_path = Pathname.pwd + 'Podfile'
        @project_path = argv.shift_argument
        @project_paths = Pathname.pwd.children.select { |pn| pn.extname == '.xcodeproj' }
        super
      end

      def validate!
        super
        raise Informative, 'Existing Podfile found in directory' unless config.podfile_path_in_dir(Pathname.pwd).nil?
        if @project_path
          help! "Xcode project at #{@project_path} does not exist" unless File.exist? @project_path
          project_path = @project_path
        else
          raise Informative, 'No Xcode project found, please specify one' unless @project_paths.length > 0
          raise Informative, 'Multiple Xcode projects found, please specify one' unless @project_paths.length == 1
          project_path = @project_paths.first
        end
        @xcode_project = Xcodeproj::Project.open(project_path)
      end

      def run
        @podfile_path.open('w') { |f| f << podfile_template(@xcode_project) }
      end

      private

      # @param  [Xcodeproj::Project] project
      #         The xcode project to generate a podfile for.
      #
      # @return [String] the text of the Podfile for the provided project
      #
      def podfile_template(project)
        podfile = ''
        podfile << "project '#{@project_path}'\n\n" if @project_path
        podfile << <<-PLATFORM.strip_heredoc
          # Uncomment this line to define a global platform for your project
          # platform :ios, '9.0'
          # Uncomment this line if you're using Swift
          # use_frameworks!
        PLATFORM

        # Split out the targets into app and test targets
        all_app_targets = project.native_targets.reject { |t| t.name =~ /tests?/i }
        all_tests_targets = project.native_targets.select { |t| t.name =~ /tests?/i }

        # Create an array of [app, (optional)test] target pairs
        app_test_pairs = all_app_targets.map do |target|
          test = all_tests_targets.find { |t| t.name.start_with? target.name }
          [target, test].compact
        end

        app_test_pairs.each do |target_pair|
          podfile << target_module(target_pair)
        end
      end

      # @param  [[Xcodeproj::PBXTarget]] targets
      #         An array which always has a target as it's first item
      #         and may optionally contain a second target as its test target
      #
      # @return [String] the text for the target module
      #
      def target_module(targets)
        app = targets.first
        target_module = "\ntarget '#{app.name.gsub(/'/, "\\\\\'")}' do\n"
        target_module << template_contents(config.default_podfile_path, "  ")

        test = targets[1]
        if test
          target_module << "\n  target '#{test.name.gsub(/'/, "\\\\\'")}' do\n"
          target_module << "        inherit! :search_paths\n"
          target_module << template_contents(config.default_test_podfile_path, "    ")
          target_module << "\n  end\n"
        end

        target_module << "\nend\n"
      end

      # @param  [[Xcodeproj::PBXTarget]] targets
      #         An array which always has a target as it's first item
      #         and may optionally contain a second target as its test target
      #
      # @return [String] the text for the target module
      #
      def template_contents(path, prefix)
        if path.exist?
          path.read.chomp.lines.map { |line| "#{prefix}#{line}" }.join("\n")
        else
          ''
        end
      end
    end
  end
end
