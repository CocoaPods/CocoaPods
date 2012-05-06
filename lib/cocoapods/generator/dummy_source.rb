module Pod
  module Generator
    class DummySource
      def save_as(pathname)
        pathname.open('w') do |source|
          source.puts "@interface PodsDummy : NSObject"
          source.puts "@end"
          source.puts "@implementation PodsDummy"
          source.puts "@end"
        end
      end
    end
  end
end
