module Pod
  class Command
    class Install < Command
      def self.banner
%{Installing dependencies of a pod spec:

    $ pod install [NAME] [PROJECT]

      Downloads all dependencies of the specified podspec file `NAME',
      creates an Xcode Pods library project in `./Pods', and sets up `PROJECT' 
      to use the specified pods (if `PROJECT' is given). In case `NAME' is
      omitted it defaults to either `Podfile' or `*.podspec' in the current
      working directory.
}
      end

      def self.options
        "    --no-clean  Leave SCM dirs like `.git' and `.svn' in tact after downloading\n" +
        super
      end

      def initialize(argv)
        config.clean = !argv.option('--no-clean')
        projpath = argv.shift_argument
        projpath =~ /\.xcodeproj\/?$/ ? @projpath = projpath : podspec = projpath
        @podspec = Pathname.new(podspec) if podspec
        @projpath ||= argv.shift_argument
        super unless argv.empty?
      end

      def run
        spec = nil
        if @podspec
          if @podspec.exist?
            spec = Specification.from_file(@podspec)
          else
            raise Informative, "The specified podspec `#{@podspec}' doesn't exist."
          end
        else
          unless spec = config.rootspec
            raise Informative, "No `Podfile' or `.podspec' file found in the current working directory."
          end
        end
        installer = Installer.new(spec)
        installer.install!
        installer.configure_project(@projpath) if @projpath
      end
    end
  end
end
