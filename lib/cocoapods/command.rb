require 'colored'
require 'claide'

module Pod
  class PlainInformative
    include CLAide::InformativeError
  end

  class Command < CLAide::Command

    require 'cocoapods/command/help'
    require 'cocoapods/command/inter_process_communication'
    require 'cocoapods/command/lib'
    require 'cocoapods/command/list'
    require 'cocoapods/command/outdated'
    require 'cocoapods/command/podfile_info'
    require 'cocoapods/command/project'
    require 'cocoapods/command/push'
    require 'cocoapods/command/repo'
    require 'cocoapods/command/search'
    require 'cocoapods/command/setup'
    require 'cocoapods/command/spec'

    self.abstract_command = true
    self.default_subcommand = 'install'
    self.command = 'pod'
    self.description = 'CocoaPods, the Objective-C library package manager.'

    def self.options
      [
        ['--silent',   'Show nothing'],
        ['--version',  'Show the version of CocoaPods'],
      ].concat(super)
    end

    def self.parse(argv)
      command = super
      unless SourcesManager.master_repo_functional? || command.is_a?(Setup) || command.is_a?(Repo::Add) || ENV['SKIP_SETUP']
        Setup.new(CLAide::ARGV.new([])).run
      end
      command
    end

    def self.run(argv)
      argv = CLAide::ARGV.new(argv)
      if argv.flag?('version')
        puts VERSION
        exit!(0)
      end
      super(argv)
      UI.print_warnings
    end

    def self.report_error(exception)
      if exception.is_a?(Interrupt)
        puts "[!] Cancelled".red
        Config.instance.verbose? ? raise : exit(1)
      else
        if ENV['COCOA_PODS_ENV'] != 'development'
          puts UI::ErrorReport.report(exception)
          exit 1
        else
          raise exception
        end
      end
    end

    # @todo If a command is run inside another one some settings which where
    #       true might return false.
    #
    # @todo We should probably not even load colored unless needed.
    #
    # @todo Move silent flag to CLAide.
    #
    # @note It is important that the commands don't override the default
    #       settings if their flag is missing (i.e. their value is nil)
    #
    def initialize(argv)
      super
      config.silent = argv.flag?('silent', config.silent)
      config.verbose = self.verbose? unless self.verbose.nil?
      unless self.colorize_output?
        String.send(:define_method, :colorize) { |string , _| string }
      end
    end

    #-------------------------------------------------------------------------#

    include Config::Mixin

    private

    # Checks that the podfile exists.
    #
    # @raise  If the podfile does not exists.
    #
    # @return [void]
    #
    def verify_podfile_exists!
      unless config.podfile
        raise Informative, "No `Podfile' found in the current working directory."
      end
    end

    # Checks that the lockfile exists.
    #
    # @raise  If the lockfile does not exists.
    #
    # @return [void]
    #
    def verify_lockfile_exists!
      unless config.lockfile
        raise Informative, "No `Podfile.lock' found in the current working directory, run `pod install'."
      end
    end
  end
end

