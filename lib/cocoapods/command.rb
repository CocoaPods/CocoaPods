module Pod
  class Command
    autoload :Install, 'cocoapods/command/install'
    autoload :Repo,    'cocoapods/command/repo'
    autoload :Search,  'cocoapods/command/search'
    autoload :List,    'cocoapods/command/list'
    autoload :Setup,   'cocoapods/command/setup'
    autoload :Spec,    'cocoapods/command/spec'

    class Help < Informative
      def initialize(command_class, argv)
        @command_class, @argv = command_class, argv
      end

      def message
        [
          @command_class.banner,
          '',
          'Options',
          '-------',
          '',
          @command_class.options
        ].join("\n")
      end
    end

    class ARGV < Array
      def options;        select { |x| x.to_s[0,1] == '-' };   end
      def arguments;      self - options;                      end
      def option(name);   !!delete(name);                      end
      def shift_argument; (arg = arguments[0]) && delete(arg); end
    end

    def self.banner
      "To see help for the available commands run:\n" \
      "\n" \
      "  * $ pod setup --help\n" \
      "  * $ pod search --help\n" \
      "  * $ pod list --help\n" \
      "  * $ pod install --help\n" \
      "  * $ pod repo --help\n" \
      "  * $ pod spec --help"
    end

    def self.options
      "    --help      Show help information\n" \
      "    --silent    Print nothing\n" \
      "    --verbose   Print more information while working\n" \
      "    --version   Prints the version of CocoaPods"
    end

    def self.run(*argv)
      parse(*argv).run
    rescue Exception => e
      unless e.is_a?(Informative)
        puts "Oh no, an error occurred. Please run with `--verbose' and report " \
             "on https://github.com/CocoaPods/CocoaPods/issues."
        puts ""
      end
      puts e.message
      puts *e.backtrace if Config.instance.verbose
      exit 1
    end

    def self.parse(*argv)
      argv = ARGV.new(argv)
      raise Informative, VERSION if argv.option('--version')

      show_help = argv.option('--help')
      Config.instance.silent = argv.option('--silent')
      Config.instance.verbose = argv.option('--verbose')

      command_class = case argv.shift_argument
      when 'install' then Install
      when 'repo'    then Repo
      when 'search'  then Search
      when 'list'    then List
      when 'setup'   then Setup
      when 'spec'    then Spec
      end

      if show_help || command_class.nil?
        raise Help.new(command_class || self, argv)
      else
        command_class.new(argv)
      end
    end

    include Config::Mixin

    def initialize(argv)
      raise Help.new(self.class, argv)
    end
  end
end

