require 'spec_helper/temporary_directory'

class Pod::Command
  attr_accessor :output
  def puts(msg = '') (@output ||= '') << "#{msg}\n" end
end


module SpecHelper
  module Command
    def command(*argv)
      argv << '--no-color'
      Pod::Command.parse(*argv)
    end

    def run_command(*args)
      Dir.chdir(SpecHelper.temporary_directory) do
        command = command(*args)
        command.run
        command.output
      end
    end
  end
end
