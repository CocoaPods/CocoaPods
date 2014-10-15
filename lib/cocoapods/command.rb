require 'colored'
require 'claide'

module Resolver
  require 'resolver'
  class ResolverError
    include CLAide::InformativeError
  end
end

module Pod
  class PlainInformative
    include CLAide::InformativeError
  end

  class Command < CLAide::Command
    require 'cocoapods/command/inter_process_communication'
    require 'cocoapods/command/lib'
    require 'cocoapods/command/list'
    require 'cocoapods/command/outdated'
    require 'cocoapods/command/project'
    require 'cocoapods/command/repo'
    require 'cocoapods/command/search'
    require 'cocoapods/command/setup'
    require 'cocoapods/command/spec'
    require 'cocoapods/command/init'

    self.abstract_command = true
    self.command = 'pod'
    self.version = VERSION
    self.description = 'CocoaPods, the Objective-C library package manager.'
    self.plugin_prefix = 'cocoapods'

    [Install, Update, Outdated, IPC::Podfile, IPC::Repl].each { |c| c.send(:include, ProjectDirectory) }

    def self.options
      [
        ['--silent',   'Show nothing'],
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
      help! 'You cannot run CocoaPods as root.' if Process.uid == 0
      super(argv)
      UI.print_warnings
    end

    def self.report_error(exception)
      case exception
      when Interrupt
        puts '[!] Cancelled'.red
        Config.instance.verbose? ? raise : exit(1)
      when SystemExit
        raise
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
      config.verbose = self.verbose? unless verbose.nil?
      unless self.ansi_output?
        String.send(:define_method, :colorize) { |string, _| string }
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
        raise Informative, "No `Podfile' found in the project directory."
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
        raise Informative, "No `Podfile.lock' found in the project directory, run `pod install'."
      end
    end
  end
end
