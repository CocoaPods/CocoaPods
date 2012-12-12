require 'colored'
require 'claide'

module Pod
  class PlainInformative
    include CLAide::InformativeError
  end

  class Command < CLAide::Command

    self.abstract_command = true
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
      unless SourcesManager.master_repo_functional? || command.is_a?(Setup) || ENV['SKIP_SETUP']
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
    end

    def self.report_error(error)
      if error.is_a?(Interrupt)
        puts "[!] Cancelled".red
        Config.instance.verbose? ? raise : exit(1)
      else
        puts UI::ErrorReport.report(error)
        exit 1
      end
    end

    # @todo If a command is run inside another one some settings which where
    #       true might return false.
    #
    def initialize(argv)
      config.silent ||= argv.flag?('silent')
      super
      config.verbose ||= self.verbose?
      # TODO we should probably not even load colored unless needed
      String.send(:define_method, :colorize) { |string , _| string } unless self.colorize_output?
    end

    #-------------------------------------------------------------------------#

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
