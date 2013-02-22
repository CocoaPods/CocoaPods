module Pod

  # @note as some outputs wraps strings
  #
  module UI
    @output = ''
    @warnings = ''

    class << self
      attr_accessor :output
      attr_accessor :warnings

      # @todo Allow to specify whether the text should be wrapped with an
      #       environment variable and remove the new feed replacement.

      def puts(message = '')
        # Wrapping can bite in tests.
        @output << "#{message}".gsub(/\n/,'')
      end

      def warn(message = '', actions = [])
        # Wrapping can bite in tests.
        @warnings << "#{message}".gsub(/\n/,'')
      end
    end
  end
end
