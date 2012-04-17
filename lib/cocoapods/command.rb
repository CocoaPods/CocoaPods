require 'colored'

module Pod
  class Command
    autoload :ErrorReport, 'cocoapods/command/error_report'
    autoload :Install,     'cocoapods/command/install'
    autoload :List,        'cocoapods/command/list'
    autoload :Presenter,   'cocoapods/command/presenter'
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
          @command_class.banner,
          '',
          'Options',
          '-------',
          '',
          options
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
      [
        ['--help',    'Show help information'],
        ['--silent',  'Print nothing'],
        ['--verbose', 'Print more information while working'],
        ['--version', 'Prints the version of CocoaPods'],
      ]
    end

    def self.run(*argv)
      bin_version = Gem::Version.new(VERSION)
      last_version = bin_version
      Source.all.each { |source|
        file = source.repo + 'CocoaPods-version.txt'
        next unless file.exist?
        repo_min_version  = Gem::Version.new(YAML.load_file(file)[:min])
        repo_last_version = Gem::Version.new(YAML.load_file(file)[:last])
        last_version = repo_last_version if repo_last_version && repo_last_version > last_version
        if repo_min_version > bin_version
          raise Informative, "\n[!] The repo `#{source}' requires CocoaPods version #{repo_version}\n".red +
            "\nPlease, update your gem\n\n"
        end
      }
      puts "\n-> Cocoapods #{last_version} is available \n".green.reversed if last_version > bin_version

      Setup.new(ARGV.new).run_if_needed
      parse(*argv).run
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

