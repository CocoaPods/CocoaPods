module Pod
  module Generator
    # Generates a header file.
    #
    # According to the platform the header imports `UIKit/UIKit.h` or
    # `Cocoa/Cocoa.h`.
    #
    class Header
      # @return [Symbol] the platform for which the prefix header will be
      #         generated.
      #
      attr_reader :platform

      # @return [Array<String>] The list of the headers to import.
      #
      attr_reader :imports

      # @param  [Symbol] platform
      #         @see platform
      #
      def initialize(platform)
        @platform = platform
        @imports = []
      end

      # Generates the contents of the header according to the platform.
      #
      # @note   If the platform is iOS an import call to `UIKit/UIKit.h` is
      #         added to the top of the prefix header. For OS X `Cocoa/Cocoa.h`
      #         is imported.
      #
      # @return [String]
      #
      def generate
        result = ""
        result << generate_platform_import_header

        result << "\n"

        imports.each do |import|
          result << %|#import "#{import}"\n|
        end

        result
      end

      # Generates and saves the header to the given path.
      #
      # @param  [Pathname] path
      #         The path where the header should be stored.
      #
      # @return [void]
      #
      def save_as(path)
        path.open('w') { |header| header.write(generate) }
      end

      #-----------------------------------------------------------------------#

      protected

      # Generates the contents of the header according to the platform.
      #
      # @note   If the platform is iOS an import call to `UIKit/UIKit.h` is
      #         added to the top of the header. For OS X `Cocoa/Cocoa.h` is
      #         imported.
      #
      # @return [String]
      #
      def generate_platform_import_header
        "#import #{platform == :ios ? '<UIKit/UIKit.h>' : '<Cocoa/Cocoa.h>'}\n"
      end
    end
  end
end
