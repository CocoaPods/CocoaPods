require 'xcodeproj'
require 'active_support/core_ext/string/strip'

module Pod
  class Command
    class Init < Command

      self.summary = 'Generate a Podfile for the current directory.'
      self.description = <<-DESC
        Creates a Podfile for the current directory if none currently exists. If
        an Xcode project file is specified or if there is only a single project
        file in the current directory, targets will be automatically generated
        based on targets defined in the project.

        It is possible to specify a list of dependencies which will be used by
        the template in the `Podfile.default` (normal targets) `Podfile.test`
        (test targets) files which should be stored in the
        `~/.cocoapods/templates` folder.
      DESC
      self.arguments = '[XCODEPROJ]'

      def initialize(argv)
        @podfile_path = Pathname.pwd + "Podfile"
        @project_path = argv.shift_argument
        @project_paths = Pathname.pwd.children.select { |pn| pn.extname == '.xcodeproj' }
        super
      end

      def validate!
        super
        raise Informative, "Existing Podfile found in directory" unless config.podfile.nil?
        if @project_path
          help! "Xcode project at #{@project_path} does not exist" unless File.exist? @project_path
        else
          raise Informative, "No xcode project found, please specify one" unless @project_paths.length > 0
          raise Informative, "Multiple xcode projects found, please specify one" unless @project_paths.length == 1
          @project_path = @project_paths.first
        end
        @xcode_project = Xcodeproj::Project.new(@project_path)
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
        podfile = <<-PLATFORM.strip_heredoc
          # Uncomment this line to define a global platform for your project
          # platform :ios, "6.0"
        PLATFORM
        if config.default_podfile_path.exist?
          open(config.default_podfile_path, 'r') { |f| podfile << f.read }
        end
        for target in project.targets
          podfile << target_module(target)
        end
        podfile << "\n"
      end

      # @param  [Xcodeproj::PBXTarget] target
      #         A target to generate a Podfile target module for.
      #
      # @return [String] the text for the target module
      #
      def target_module(target)
        target_module = <<-TARGET.strip_heredoc


          target "#{target.name}" do
        TARGET
        if config.default_test_podfile_path.exist? and target.name =~ /tests?/i
          open(config.default_test_podfile_path, 'r') { |f| target_module << f.read }
        end
        target_module << "\nend"
      end
    end
  end
end
