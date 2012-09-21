module Pod
  module UI
    @output = ''

    class << self
      attr_accessor :output

      def puts(message = '')
        @output << "#{message}"
      end
    end
  end
end
