module Pod
  module UI
    @output = ''
    @warnings = ''

    class << self
      attr_accessor :output
      attr_accessor :warnings

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
