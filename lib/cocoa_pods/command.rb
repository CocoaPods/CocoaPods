module Pod
  class Command
    autoload :Help,  'cocoa_pods/command/help'
    autoload :Setup, 'cocoa_pods/command/setup'
    autoload :Spec,  'cocoa_pods/command/spec'
    autoload :Repo,  'cocoa_pods/command/repo'

    def self.parse(*argv)
      argv = argv.dup
      command = case argv.shift
      when 'help'  then Help
      when 'setup' then Setup
      when 'spec'  then Spec
      when 'repo'  then Repo
      end
      command.new(*argv)
    end

    def initialize(*argv)
      raise "unknown argument(s): #{argv.join(', ')}" unless argv.empty?
    end

    def run
    end
  end
end
