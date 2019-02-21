module Pod
  class Target
    class FrameworkPaths
      # @return [String] the path to the .framework
      #
      attr_reader :source_path

      # @return [String, Nil] the dSYM path, if one exists
      #
      attr_reader :dsym_path

      # @return [Array, Nil] the bcsymbolmap files path array, if one exists
      #
      attr_reader :bcsymbolmap_paths

      def initialize(source_path, dsym_path = nil, bcsymbolmap_paths = nil)
        @source_path = source_path
        @dsym_path = dsym_path
        @bcsymbolmap_paths = bcsymbolmap_paths
      end

      def ==(other)
        if other.class == self.class
          other.source_path == @source_path && other.dsym_path == @dsym_path && other.bcsymbolmap_paths == @bcsymbolmap_paths
        else
          false
        end
      end

      alias eql? ==

      def hash
        [source_path, dsym_path, bcsymbolmap_paths].hash
      end

      def all_paths
        [source_path, dsym_path, bcsymbolmap_paths].flatten.compact
      end
    end
  end
end
