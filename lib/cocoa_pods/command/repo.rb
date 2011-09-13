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

      def initialize(argv)
        case @action = argv.arguments[0]
        when 'add'
          unless (@name = argv[1]) && (@url = argv[2])
            raise ArgumentError, "needs a NAME and URL"
          end
        when 'update'
          @name = argv[1]
        else
          super
        end
      end

      def dir
        config.repos_dir + @name
      end

      def run
        send @action
      end

      def add
        puts "==> Cloning spec repo `#{@name}' from `#{@url}'"
        config.repos_dir.mkpath
        Dir.chdir(config.repos_dir) { git("clone #{@url} #{@name}") }
      end

      def update
        dirs = @name ? [dir] : config.repos_dir.children
        dirs.each do |dir|
          puts "==> Updating spec repo `#{dir.basename}'"
          Dir.chdir(dir) { git("pull") }
        end
      end
    end
  end
end

