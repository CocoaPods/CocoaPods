require 'cocoapods-downloader'
require 'claide/informative_error'

module Pod
  module Downloader
    class DownloaderError; include CLAide::InformativeError; end

    class Base
      override_api do

        def execute_command(executable, command, raise_on_failure = false)
          Executable.execute_command(executable, command, raise_on_failure)
        rescue CLAide::InformativeError => e
          raise DownloaderError, e.message
        end

        # Indicates that an action will be performed. The action is passed as a
        # block.
        #
        # @param  [String] message
        #         The message associated with the action.
        #
        # @yield  The action, this block is always executed.
        #
        # @return [void]
        #
        def ui_action(message)
          UI.section(" > #{message}", '', 1) do
            yield
          end
        end

        # Indicates that a minor action will be performed. The action is passed
        # as a block.
        #
        # @param  [String] message
        #         The message associated with the action.
        #
        # @yield  The action, this block is always executed.
        #
        # @return [void]
        #
        def ui_sub_action(message)
          UI.section(" > #{message}", '', 2) do
            yield
          end
        end

        # Prints an UI message.
        #
        # @param  [String] message
        #         The message associated with the action.
        #
        # @return [void]
        #
        def ui_message(message)
          UI.puts message
        end

      end
    end
  end
end
