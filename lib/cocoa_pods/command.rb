module Pod
  class Command
    autoload :Install, 'cocoa_pods/command/install'
    autoload :Repo,    'cocoa_pods/command/repo'
    autoload :Setup,   'cocoa_pods/command/setup'
    autoload :Spec,    'cocoa_pods/command/spec'

    class Help
      def initialize(command_class, argv)
        @command_class, @argv = command_class, argv
      end

      def run
        puts @command_class.banner
        puts
        puts "Options"
        puts "-------"
        puts
        puts @command_class.options
      end
    end

    def self.banner
      "### Commands\n" +
      "\n" +
      "  * setup\n" +
      "  * install\n" +
      "  * repo\n" +
      "  * spec"
    end

    def self.options
      "    --help      Show help information\n" +
      "    --verbose   Print more information while working"
    end

    def self.parse(*argv)
      argv = argv.dup
      show_help = argv.delete('--help')
      Config.instance.verbose = !!argv.delete('--verbose')

      command_class = case argv.shift
      when 'install' then Install
      when 'repo'    then Repo
      when 'setup'   then Setup
      when 'spec'    then Spec
      end

      if show_help || command_class.nil?
        Help.new(command_class || self, argv)
      else
        command_class.new(*argv)
      end
    end

    include Config::Mixin

    def initialize(*argv)
      raise ArgumentError, "unknown argument(s): #{argv.join(', ')}" unless argv.empty?
    end
  end
end
