require 'colored'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/string/strip.rb'

module Pod
  class Command < CLIAide::Command
    autoload :ErrorReport, 'cocoapods/command/error_report'
    autoload :Linter,      'cocoapods/command/linter'

    self.abstract_command = true
    self.description = 'CocoaPods, the Objective-C library package manager.'

    def self.options
      [
        ['--silent',   'Print nothing'],
        ['--no-color', 'Print output without color'],
        ['--version',  'Prints the version of CocoaPods'],
      ].concat(super)
    end

    #def self.run(argv)
      #super
      #p Config.instance.verbose?
    #end

    #def self.run(*argv)
      #sub_command = parse(*argv)
      #unless sub_command.is_a?(Setup) || ENV['SKIP_SETUP']
        #Setup.new(ARGV.new).run_if_needed
      #end
      #sub_command.run
      #UI.puts

    #rescue Interrupt
      #puts "[!] Cancelled".red
      #Config.instance.verbose? ? raise : exit(1)

    #rescue Exception => e
      #if e.is_a?(PlainInformative) || ENV['COCOA_PODS_ENV'] == 'development' # also catches Informative
        #puts e.message
        #puts *e.backtrace if Config.instance.verbose? || ENV['COCOA_PODS_ENV'] == 'development'
      #else
        #puts ErrorReport.report(e)
      #end
      #exit 1
    #end

    #def self.parse(*argv)
      #argv = ARGV.new(argv)
      #if argv.option('--version')
        #puts VERSION
        #exit!(0)
      #end

      #show_help = argv.option('--help')
      #Config.instance.silent = argv.option('--silent')
      #Config.instance.verbose = argv.option('--verbose')

      #String.send(:define_method, :colorize) { |string , _| string } if argv.option( '--no-color' )

      #command_class = case command_argument = argv.shift_argument
      #when 'install'  then Install
      #when 'list'     then List
      #when 'outdated' then Outdated
      #when 'push'     then Push
      #when 'repo'     then Repo
      #when 'search'   then Search
      #when 'setup'    then Setup
      #when 'spec'     then Spec
      #when 'update'   then Update
      #end

      #if command_class.nil?
        #raise Help.new(self, argv, command_argument)
      #elsif show_help
        #raise Help.new(command_class, argv)
      #else
        #command_class.new(argv)
      #end
    #end

    def initialize(argv)
      super
      config.verbose = verbose?
    end

    include Config::Mixin

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
  end
end

require 'cocoapods/command/list'
require 'cocoapods/command/outdated'
require 'cocoapods/command/project'
require 'cocoapods/command/push'
require 'cocoapods/command/repo'
require 'cocoapods/command/search'
require 'cocoapods/command/setup'
require 'cocoapods/command/spec'
