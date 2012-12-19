module Pod
  module Generator

    # Generates a header which allows to inspect at compile time the installed
    # pods and the installed specifications of a pod.
    #
    # Example output:
    #
    #     #define __COCOA_PODS
    #
    #     #define __POD_AFIncrementaStore
    #     #define __POD_AFNetworking
    #     #define __POD_libextobjc_EXTConcreteProtocol
    #     #define __POD_libextobjc_EXTKeyPathCoding
    #     #define __POD_libextobjc_EXTScope
    #
    # Example usage:
    #
    #     #ifdef __COCOA_PODS
    #       #ifdef __POD__AFNetworking
    #         #import "MYLib+AFNetworking.h"
    #       #endif
    #     #else
    #       // Non CocoaPods code
    #     #endif
    #
    class TargetHeader

      # @return [Array<LocalPod>] the specifications installed for the target.
      #
      attr_reader :specs

      # @param  [Array<LocalPod>] pods @see pods
      #
      def initialize(specs)
        @specs = specs
      end

      # Generates and saves the file.
      #
      # @param  [Pathname] pathname
      #         The path where to save the generated file.
      #
      # @return [void]
      #
      def save_as(pathname)
        pathname.open('w') do |source|
          source.puts "#define __COCOA_PODS"
          source.puts
          specs.each do |specs|
            source.puts "#define __POD_#{specs.name.gsub(/[^\w]/,'_')}"
          end
        end
      end
    end
  end
end
