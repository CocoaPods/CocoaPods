require 'colored'

module Pod
  class Command
    autoload :ErrorReport, 'cocoapods/command/error_report'
    autoload :Install,     'cocoapods/command/install'
    autoload :List,        'cocoapods/command/list'
    autoload :Presenter,   'cocoapods/command/presenter'
    autoload :Push,        'cocoapods/command/push'
    autoload :Repo,        'cocoapods/command/repo'
    autoload :Search,      'cocoapods/command/search'
    autoload :Setup,       'cocoapods/command/setup'
    autoload :Spec,        'cocoapods/command/spec'

    class Help < Informative
      def initialize(command_class, argv)
        @command_class, @argv = command_class, argv
      end

      def message
        [
          '',
          @command_class.banner.gsub(/\$ pod (.*)/, '$ pod \1'.green),
          '',
          'Options:',
          '',
          options,
          "\n",
        ].join("\n")
      end

      private

      def options
        options  = @command_class.options
        keys     = options.map(&:first)
        key_size = keys.inject(0) { |size, key| key.size > size ? key.size : size }
        options.map { |key, desc| "    #{key.ljust(key_size)}   #{desc}" }.join("\n")
      end
    end

    class ARGV < Array
      def options;        select { |x| x.to_s[0,1] == '-' };   end
      def arguments;      self - options;                      end
      def option(name);   !!delete(name);                      end
      def shift_argument; (arg = arguments[0]) && delete(arg); end
    end

    def self.banner
      commands = ['install', 'list', 'push', 'repo', 'search', 'setup', 'spec'].sort
      banner   = "\nTo see help for the available commands run:\n\n"
      commands.each {|cmd| banner << "  * $ pod #{cmd.green} --help\n"}
      banner
    end

    def self.options
      [
        ['--help',     'Show help information'],
        ['--silent',   'Print nothing'],
        ['--no-color', 'Print output without color'],
        ['--verbose',  'Print more information while working'],
        ['--version',  'Prints the version of CocoaPods'],
      ]
    end

    def self.run(*argv)
      sub_command = parse(*argv)
      Setup.new(ARGV.new).run_if_needed
      sub_command.run

    rescue Interrupt
      puts "[!] Cancelled".red
      Config.instance.verbose? ? raise : exit(1)

    rescue Exception => e
      if e.is_a?(Informative)
        puts e.message
        puts *e.backtrace if Config.instance.verbose?
      else
        puts ErrorReport.report(e)
      end
      exit 1
    end

    def self.parse(*argv)
      argv = ARGV.new(argv)
      raise Informative, VERSION if argv.option('--version')

      show_help = argv.option('--help')
      Config.instance.silent = argv.option('--silent')
      Config.instance.verbose = argv.option('--verbose')

      String.send(:define_method, :colorize) { |string , _| string } if argv.option( '--no-color' )

      command_class = case argv.shift_argument
      when 'install' then Install
      when 'repo'    then Repo
      when 'search'  then Search
      when 'list'    then List
      when 'setup'   then Setup
      when 'spec'    then Spec
      when 'push'    then Push
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

    private

    def print_title(title, only_verbose = true)
      if config.verbose?
        puts "\n" + title.yellow
      elsif !config.silent? && !only_verbose
        puts title
      end
    end

    def print_subtitle(title, only_verbose = false)
      if config.verbose?
        puts "\n" + title.green
      elsif !config.silent? && !only_verbose
        puts title
      end
    end
  end
end

