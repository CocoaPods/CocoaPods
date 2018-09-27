module Pod
  class Target
    class FrameworkPaths
      # @return [String] the path to the .framework
      #
      attr_reader :source_path

      # @return [String, Nil] the dSYM path, if one exists
      #
      attr_reader :dsym_path

      def initialize(source_path, dsym_path = nil)
        @source_path = source_path
        @dsym_path = dsym_path
      end

      def ==(other)
        if other.class == self.class
          other.source_path == @source_path && other.dsym_path == @dsym_path
        else
          false
        end
      end

      alias eql? ==

      def hash
        if (dsym = dsym_path)
          [source_path, dsym].hash
        else
          source_path.hash
        end
      end
    end
  end
end
