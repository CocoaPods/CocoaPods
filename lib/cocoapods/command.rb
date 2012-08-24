require 'colored'

module Pod
  class Command
    autoload :ErrorReport, 'cocoapods/command/error_report'
    autoload :Install,     'cocoapods/command/install'
    autoload :List,        'cocoapods/command/list'
    autoload :Linter,      'cocoapods/command/linter'
    autoload :Outdated,    'cocoapods/command/outdated'
    autoload :Presenter,   'cocoapods/command/presenter'
    autoload :Push,        'cocoapods/command/push'
    autoload :Repo,        'cocoapods/command/repo'
    autoload :Search,      'cocoapods/command/search'
    autoload :Setup,       'cocoapods/command/setup'
    autoload :Spec,        'cocoapods/command/spec'
    autoload :Update,      'cocoapods/command/update'

    class Help < Informative
      def initialize(command_class, argv, unrecognized_command = nil)
        @command_class, @argv, @unrecognized_command = command_class, argv, unrecognized_command
      end

      def message
        message = [
          '',
          @command_class.banner.gsub(/\$ pod (.*)/, '$ pod \1'.green),
          '',
          'Options:',
          '',
          options,
          "\n",
        ].join("\n")
        message << "[!] Unrecognized command: `#{@unrecognized_command}'\n".red if @unrecognized_command
        message << "[!] Unrecognized argument#{@argv.count > 1 ? 's' : ''}: `#{@argv.join(' - ')}'\n".red unless @argv.empty?
        message
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
      commands = ['install', 'update', 'outdated', 'list', 'push', 'repo', 'search', 'setup', 'spec'].sort
      banner   = "To see help for the available commands run:\n\n"
      banner + commands.map { |cmd| "  * $ pod #{cmd.green} --help" }.join("\n")
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
      unless ENV['SKIP_SETUP']
        Setup.new(ARGV.new).run_if_needed
      end
      sub_command.run

    rescue Interrupt
      puts "[!] Cancelled".red
      Config.instance.verbose? ? raise : exit(1)

    rescue Exception => e
      if e.is_a?(PlainInformative) || ENV['COCOA_PODS_ENV'] == 'development' # also catches Informative
        puts e.message
        puts *e.backtrace if Config.instance.verbose? || ENV['COCOA_PODS_ENV'] == 'development'
      else
        puts ErrorReport.report(e)
      end
      exit 1
    end

    def self.parse(*argv)
      argv = ARGV.new(argv)
      if argv.option('--version')
        puts VERSION
        exit!(0)
      end

      show_help = argv.option('--help')
      Config.instance.silent = argv.option('--silent')
      Config.instance.verbose = argv.option('--verbose')

      String.send(:define_method, :colorize) { |string , _| string } if argv.option( '--no-color' )

      command_class = case command_argument = argv.shift_argument
      when 'install'  then Install
      when 'list'     then List
      when 'outdated' then Outdated
      when 'push'     then Push
      when 'repo'     then Repo
      when 'search'   then Search
      when 'setup'    then Setup
      when 'spec'     then Spec
      when 'update'   then Update
      end

      if command_class.nil?
        raise Help.new(self, argv, command_argument)
      elsif show_help
        raise Help.new(command_class, argv)
      else
        command_class.new(argv)
      end
    end

    include Config::Mixin

    def initialize(argv)
      raise Help.new(self.class, argv)
    end

    private

    def verify_podfile_exists!
      unless config.podfile
        raise Informative, "No `Podfile' found in the current working directory."
      end
    end

    def verify_lockfile_exists!
      unless config.lockfile
        raise Informative, "No `Podfile.lock' found in the current working directory, run `pod install'."
      end
    end

    def update_spec_repos_if_necessary!
      if @update_repo
        print_title 'Updating Spec Repositories', true
        Repo.new(ARGV.new(["update"])).run
      end
    end

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

