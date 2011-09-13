require 'executioner'
require 'fileutils'

module Pod
  class Command
    class Repo < Command
      def self.banner
%{### Managing spec-repos

    $ pod help repo

      pod repo add NAME URL
        Clones `URL' in the local spec-repos directory at `~/.cocoa-pods'. The
        remote can later be referred to by `NAME'.

      pod repo update NAME
        Updates the local clone of the spec-repo `NAME'.

      pod repo change NAME URL
        Changes the git remote of local spec-repo `NAME' to `URL'.

      pod repo cd NAME
        Changes the current working dir to the local spec-repo `NAME'.}
      end

      include Executioner
      executable :git

      def initialize(*argv)
        case @action = argv[0]
        when'add'
          unless (@name = argv[1]) && (@url = argv[2])
            raise ArgumentError, "needs a NAME and URL"
          end
        when 'update'
          @name = argv[1]
       when 'cd'
          unless @name = argv[1]
            raise ArgumentError, "needs a NAME"
          end
        else
          super
        end
      end

      def dir
        File.join(config.repos_dir, @name)
      end

      def run
        send @action
      end

      def add
        FileUtils.mkdir_p(config.repos_dir)
        Dir.chdir(config.repos_dir) { git("clone #{@url} #{@name}") }
      end

      def update
        names = @name ? [@name] : Dir.entries(config.repos_dir)[2..-1]
        names.each do |name|
          Dir.chdir(File.join(config.repos_dir, name)) { git("pull") }
        end
      end
    end
  end
end

