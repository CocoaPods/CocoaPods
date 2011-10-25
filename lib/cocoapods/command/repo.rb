require 'fileutils'

module Pod
  class Command
    class Repo < Command
      def self.banner
%{Managing spec-repos:

    $ pod help repo

      pod repo add NAME URL
        Clones `URL' in the local spec-repos directory at `~/.cocoapods'. The
        remote can later be referred to by `NAME'.

      pod repo update NAME
        Updates the local clone of the spec-repo `NAME'. If `NAME' is omitted
        this will update all spec-repos in `~/.cocoapods'.}
      end

      extend Executable
      executable :git

      def initialize(argv)
        case @action = argv.arguments[0]
        when 'add'
          unless (@name = argv[1]) && (@url = argv[2])
            raise Help, "Adding a repo needs a `name' and a `url'."
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
        puts "==> Cloning spec repo `#{@name}' from `#{@url}'" unless config.silent?
        config.repos_dir.mkpath
        Dir.chdir(config.repos_dir) { git("clone '#{@url}' #{@name}") }
      end

      def update
        dirs = @name ? [dir] : config.repos_dir.children
        dirs.each do |dir|
          puts "==> Updating spec repo `#{dir.basename}'" unless config.silent?
          Dir.chdir(dir) { git("pull") }
        end
      end
    end
  end
end

