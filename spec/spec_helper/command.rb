module SpecHelper
  module Command
    def argv(*argv)
      CLAide::ARGV.new(argv)
    end

    def command(*argv)
      argv << '--no-color'
      Pod::Command.parse(argv)
    end

    def run_command(*args)
      Dir.chdir(SpecHelper.temporary_directory) do
        Pod::UI.output = ''
        # @todo Remove this once all cocoapods has
        # been converted to use the UI.puts
        config.stubs(:silent).returns(false)
        cmd = command(*args)
        cmd.validate!
        cmd.run
        config.unstub(:silent)
        Pod::UI.output
      end
    end
  end
end
