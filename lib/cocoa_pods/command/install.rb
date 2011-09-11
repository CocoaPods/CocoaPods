module Pod
  class Command
    class Install < Command
      def run
        if spec = Specification.from_podfile(podfile)
          spec.install_dependent_specifications!(pods_root, true)
        else
          $stderr.puts "No Podfile found in current working directory."
        end
      end

      def pods_root
        Pathname.new(Dir.pwd) + 'Pods'
      end

      def podfile
        File.join(Dir.pwd, 'Podfile')
      end
    end
  end
end
