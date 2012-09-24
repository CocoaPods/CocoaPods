module Pod
  module UI
    @output = ''

    class << self
      attr_accessor :output

      def puts(message = '')
        # Wrapping can bite in tests.
        @output << "#{message}".gsub(/\n/,'')
      end
    end
  end
end
