module Pod
  class Command
    class Install < Command
      def run
        if spec = Specification.from_podfile(podfile)
          p spec
          Resolver.new(spec).resolve
        else
          $stderr.puts "No Podfile found in current working directory."
        end
      end

      def podfile
        File.join(Dir.pwd, 'Podfile')
      end
    end
  end
end
