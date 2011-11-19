module Pod
  class Command
    class Install < Command
      def self.banner
%{Installing dependencies of a project:

    $ pod install [PROJECT]

      Downloads all dependencies defined in `Podfile' and creates an Xcode
      Pods library project in `./Pods'.

      In case `PROJECT' is given, it configures it to use the specified Pods
      and generates a workspace with the Pods project and `PROJECT'. (It is
      important that once you have run this you open the workspace instead of
      `PROJECT'.) You usually specify `PROJECT' only the first time that you
      run `pod install'.
}
      end

      def self.options
        "    --no-clean  Leave SCM dirs like `.git' and `.svn' in tact after downloading\n" +
        super
      end

      def initialize(argv)
        config.clean = !argv.option('--no-clean')
        @projpath = argv.shift_argument
        super unless argv.empty?
      end

      def run
        unless podfile = config.rootspec
          raise Informative, "No `Podfile' found in the current working directory."
        end
        installer = Installer.new(podfile)
        installer.install!
        installer.configure_project(@projpath) if @projpath
      end
    end
  end
end
