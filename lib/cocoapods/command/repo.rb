require 'fileutils'

module Pod
  class Command
    class Repo < Command
      def self.banner
%{Managing spec-repos:

    $ pod repo add NAME URL

      Clones `URL' in the local spec-repos directory at `~/.cocoapods'. The
      remote can later be referred to by `NAME'.

    $ pod repo update NAME

      Updates the local clone of the spec-repo `NAME'. If `NAME' is omitted
      this will update all spec-repos in `~/.cocoapods'.

    $ pod repo set-url NAME URL

      Updates the remote `URL' of the spec-repo `NAME'.}
      end

      extend Executable
      executable :git

      def initialize(argv)
        case @action = argv.arguments[0]
        when 'add', 'set-url'
          unless (@name = argv.arguments[1]) && (@url = argv.arguments[2])
            raise Informative, "#{@action == 'add' ? 'Adding' : 'Updating the remote of'} a repo needs a `name' and a `url'."
          end
        when 'update', 'read-url'
          @name = argv.arguments[1]
        else
          super
        end
      end

      def dir
        config.repos_dir + @name
      end

      def run
        send @action.gsub('-', '_')
      end

      def add
        puts "Cloning spec repo `#{@name}' from `#{@url}'" unless config.silent?
        config.repos_dir.mkpath
        Dir.chdir(config.repos_dir) { git("clone '#{@url}' #{@name}") }
      end

      def update
        dirs = @name ? [dir] : config.repos_dir.children.select {|c| c.directory?}
        dirs.each do |dir|
          puts "Updating spec repo `#{dir.basename}'" unless config.silent?
          Dir.chdir(dir) { git("pull") }
        end
      end

      def set_url
        Dir.chdir(dir) do
          git("remote set-url origin '#{@url}'")
        end
      end

      def read_url
        Dir.chdir(dir) do
          @output = git('config --get remote.origin.url')
        end
      end

    end
  end
end

