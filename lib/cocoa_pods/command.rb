module Pod
  class Command
    include Config::Mixin

    autoload :Help,    'cocoa_pods/command/help'
    autoload :Install, 'cocoa_pods/command/install'
    autoload :Repo,    'cocoa_pods/command/repo'
    autoload :Setup,   'cocoa_pods/command/setup'
    autoload :Spec,    'cocoa_pods/command/spec'

    def self.parse(*argv)
      argv = argv.dup
      command = case argv.shift
      when 'help'    then Help
      when 'install' then Install
      when 'repo'    then Repo
      when 'setup'   then Setup
      when 'spec'    then Spec
      end
      command.new(*argv)
    end

    def initialize(*argv)
      raise ArgumentError, "unknown argument(s): #{argv.join(', ')}" unless argv.empty?
    end
  end
end
