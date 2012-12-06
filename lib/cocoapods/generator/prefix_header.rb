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
      # generated.
      #
      attr_reader :platform

      # @return [Array<LocalPod>] the LocalPod for the target for which the
      # prefix header needs to be generated.
      #
      attr_reader :pods

      # @param  [Platform] platform @see platform
      #
      # @param  [Array<LocalPod>]   @see pods
      #
      def initialize(platform, pods)
        @platform = platform
        @pods = pods
      end

      #--------------------------------------#

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

        pods.each do |pod|
          result << "\n"
          if prefix_header_contents = pod.top_specification.prefix_header_contents
            result << prefix_header_contents
            result << "\n"
          elsif prefix_header = pod.prefix_header_file
            result << prefix_header.read
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
