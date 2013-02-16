module Pod
  module Hooks

    # Stores the information of
    #
    # Was target definition
    #
    class LibraryData

      def dependencies
        library.target_definition.dependencies
      end

      def initialize(library)
        @library = library
      end

      private

      attr_reader :library

    end
  end
end




