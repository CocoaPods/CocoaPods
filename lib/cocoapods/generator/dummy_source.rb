module Pod
  module Generator
    class DummySource
      attr_reader :class_name

      def initialize(class_name_identifier)
        validated_class_name_identifier = class_name_identifier.gsub(/[^0-9a-z_]/i, '_')
        @class_name = "PodsDummy_#{validated_class_name_identifier}"
      end

      def save_as(pathname)
        pathname.open('w') do |source|
          source.puts '#import <Foundation/Foundation.h>'
          source.puts "@interface #{class_name} : NSObject"
          source.puts '@end'
          source.puts "@implementation #{class_name}"
          source.puts '@end'
        end
      end
    end
  end
end
