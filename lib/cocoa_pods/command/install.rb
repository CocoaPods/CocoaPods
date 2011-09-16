module Pod
  class Command
    class Install < Command
      def self.banner
%{### Installing dependencies of a spec

    $ pod install [NAME]

      Downloads all dependencies of the specified podspec file `NAME' and
      creates an Xcode Pods library project of the specified podspec file
      `NAME'. In case `NAME' is omitted, it defaults to `Podfile' in the
      current working directory.
}
      end

      def self.options
        "    --no-clean  Leave SCM dirs like `.git' and `.svn' in tact after downloading\n" +
        super
      end

      def initialize(argv)
        config.clean = !argv.option('--no-clean')
        if podspec = argv.shift_argument
          @podspec = Pathname.new(podspec)
        end
        super unless argv.empty?
      end

      def run
        spec = nil
        if @podspec
          if @podspec.exist?
            spec = Specification.from_podspec(@podspec)
          else
            raise Help, "The specified podspec `#{@podspec}' doesn't exist."
          end
        else
          if config.project_podfile.exist?
            spec = Specification.from_podfile(config.project_podfile)
          else
            raise Help, "No Podfile found in current working directory."
          end
        end
        Installer.new(spec).install!
      end
    end
  end
end
