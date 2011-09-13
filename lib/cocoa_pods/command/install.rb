module Pod
  class Command
    class Install < Command
      def run
        if config.project_podfile.exist?
          spec = Specification.from_podfile(config.project_podfile)
          Installer.new(spec, config.project_pods_root).install!
        else
          $stderr.puts "No Podfile found in current working directory."
        end
      end
    end
  end
end
