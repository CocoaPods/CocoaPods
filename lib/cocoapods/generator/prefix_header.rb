module Pod
  module Generator

    # Generates a prefix header file for a Pods library. The prefix header is
    # generated according to the platform of the target and the pods.
    #
    # According to the platform the prefix header imports `UIKit/UIKit.h` or
    # `Cocoa/Cocoa.h`.
    #
    class PrefixHeader

      # @return [Platform] the platform for which the prefix header will be
      #         generated.
      #
      attr_reader :file_accessors
      attr_reader :platform

      # @return [Array<LocalPod>] the LocalPod for the target for which the
      #         prefix header needs to be generated.
      #
      # attr_reader :consumers

      # @return [Array<String>] any header to import (with quotes).
      #
      attr_reader :imports

      # @param  [Platform] platform     @see platform
      # @param  [Array<LocalPod>] consumers  @see consumers
      #
      def initialize(file_accessors, platform)
        @file_accessors = file_accessors
        @platform = platform
        @imports = []
      end

      # Generates the contents of the prefix header according to the platform
      # and the pods.
      #
      # @note   If the platform is iOS an import call to `UIKit/UIKit.h` is
      #         added to the top of the prefix header. For OS X `Cocoa/Cocoa.h`
      #         is imported.
      #
      # @return [String]
      #
      # @todo   Subspecs can specify prefix header information too.
      #
      def generate
        result =  "#ifdef __OBJC__\n"
        result << "#import #{platform == :ios ? '<UIKit/UIKit.h>' : '<Cocoa/Cocoa.h>'}\n"
        result << "#endif\n"

        imports.each do |import|
          result << %|\n#import "#{import}"|
        end

        file_accessors.each do |file_accessor|
          result << "\n"
          if prefix_header_contents = file_accessor.spec_consumer.prefix_header_contents
            result << prefix_header_contents
            result << "\n"
          end
          if prefix_header = file_accessor.prefix_header
            result << Pathname(prefix_header).read
          end
        end
        result
      end

      # Generates and saves the prefix header to the given path.
      #
      # @param  [Pathname] path
      #         the path where the prefix header should be stored.
      #
      # @return [void]
      #
      def save_as(path)
        path.open('w') { |header| header.write(generate) }
      end

    end
  end
end
