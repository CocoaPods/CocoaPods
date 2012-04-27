module Pod
  module Generator
    class DummySource
      def initialize(label)
        @label = label
      end

      def save_as(pathname)
        pathname.open('w') do |source|
          source.puts "@interface #{@label}Dummy : NSObject"
          source.puts "@end"
          source.puts "@implementation #{@label}Dummy"
          source.puts "@end"
        end
      end
    end
  end
end
