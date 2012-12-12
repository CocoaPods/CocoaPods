require 'cocoapods-downloader'

module Pod
  module Downloader
    class Base

      override_api do
        def execute_command(executable, command, raise_on_failure = false)
          Executable.execute_command(executable, command, raise_on_failure = false)
        end

        def download_action(ui_message)
          UI.section(" > #{ui_message}", '', 1) do
            yield
          end
        end
      end

    end
  end
end
