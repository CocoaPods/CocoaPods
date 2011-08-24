require 'executioner'
require 'fileutils'

module Pod
  class Command
    class Repo < Command
      include Executioner
      executable :git

      def initialize(*argv)
        case @action = argv[0]
        when'add'
          unless (@name = argv[1]) && (@url = argv[2])
            raise ArgumentError, "needs a NAME and URL"
          end
        when 'update'
          unless @name = argv[1]
            raise ArgumentError, "needs a NAME"
          end
       when 'cd'
          unless @name = argv[1]
            raise ArgumentError, "needs a NAME"
          end
        else
          super
        end
      end

      def dir
        File.join(repos_dir, @name)
      end

      def run
        send @action
      end

      def add
        FileUtils.mkdir_p(repos_dir)
        Dir.chdir(repos_dir) { git("clone #{@url} #{@name}") }
      end

      def update
        Dir.chdir(File.join(repos_dir, @name)) { git("pull") }
      end
    end
  end
end

