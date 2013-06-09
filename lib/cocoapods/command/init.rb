require 'xcodeproj'

module Pod
  class Command
    class Init < Command

      self.summary = 'Generate a Podfile for the current directory.'
      self.description = <<-DESC
        Creates a Podfile for the current directory if none currently exists. If
        an Xcode project file is specified or if there is only a single project
        file in the current directory, targets will be automatically generated
        based on targets defined in the project.
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
        help! "Existing Podfile found in directory" if File.file? @podfile_path
        unless @project_path
          help! "No xcode project found, please specify one" unless @project_paths.length > 0
          help! "Multiple xcode projects found, please specify one" unless @project_paths.length == 1
          @project_path = @project_paths.first
        end
        help! "Xcode project at #{@project_path} does not exist" unless File.exist? @project_path
        @xcode_project = Xcodeproj::Project.new(@project_path)
      end

      def run
        @podfile_path.open('w') { |f| f << podfile_template(@xcode_project) }
      end

      def podfile_template(project)
        platforms = project.targets.map { |t| t.platform_name }.uniq
        if platforms.length == 1
          podfile = <<-PLATFORM
platform #{platforms.first}
PLATFORM
        else
          podfile = <<-PLATFORM
# Uncomment this line to define the platform for your project
platform :ios, "6.0"
PLATFORM
        end
        for target in project.targets
          podfile << target_module(target)
        end
        podfile
      end

      def target_module(target, define_platform = true)
        platform = "platform #{target.platform_name}" if define_platform
        return <<-TARGET
target :#{target.name} do
  #{platform}
end
TARGET
      end
    end
  end
end
