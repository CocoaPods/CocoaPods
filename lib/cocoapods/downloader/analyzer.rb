module Pod
  module Downloader
    class Analyzer
      attr_reader :root

      def initialize(root)
        @root = root
      end
    end
  end
end
