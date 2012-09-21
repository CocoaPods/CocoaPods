require 'spec_helper/temporary_directory'

module SpecHelper
  module Command
    def command(*argv)
      argv << '--no-color'
      Pod::Command.parse(*argv)
    end

    def run_command(*args)
      Dir.chdir(SpecHelper.temporary_directory) do
        Pod::UI.output = ''

        # TODO: remove this once all cocoapods has
        # been converted to use the UI.puts
        config_silent = config.silent?
        config.silent = false
        # Very nasty behaviour where the relative increments are
        # not reverted and lead to sections being collapsed and
        # not being printed to the output.
        Pod::UI.indentation_level = 0
        Pod::UI.title_level = 0

        command(*args).run
        config.silent = config_silent
        Pod::UI.output
      end
    end
  end
end
