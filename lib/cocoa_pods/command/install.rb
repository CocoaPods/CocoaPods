module Pod
  class Command
    class Install < Command
      def initialize(*argv)
        if podspec = argv.shift
          @podspec = Pathname.new(podspec)
        end
        super
      end

      def run
        spec = nil
        if @podspec
          if @podspec.exist?
            spec = Specification.from_podspec(@podspec)
          else
            raise "The specified podspec `#{@podspec}' doesn't exist."
          end
        else
          if config.project_podfile.exist?
            spec = Specification.from_podfile(config.project_podfile)
          else
            raise "No Podfile found in current working directory."
          end
        end
        Installer.new(spec, config.project_pods_root).install!
      end
    end
  end
end
