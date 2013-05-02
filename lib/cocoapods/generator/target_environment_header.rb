module Pod
  module Generator

    # Generates a header which allows to inspect at compile time the installed
    # pods and the installed specifications of a pod.
    #
    # Example output:
    #
    #     #define COCOAPODS_POD_AVAILABLE_ObjectiveSugar 1
    #     #define COCOAPODS_VERSION_MAJOR_ObjectiveSugar 0
    #     #define COCOAPODS_VERSION_MINOR_ObjectiveSugar 6
    #     #define COCOAPODS_VERSION_PATCH_ObjectiveSugar 2
    #
    # Example usage:
    #
    #     #ifdef COCOAPODS
    #       #ifdef COCOAPODS_POD_AVAILABLE_ObjectiveSugar
    #         #import "ObjectiveSugar.h"
    #       #endif
    #     #else
    #       // Non CocoaPods code
    #     #endif
    #
    class TargetEnvironmentHeader

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
          source.puts
          source.puts "// To check if a library is compiled with CocoaPods you"
          source.puts "// can use the `COCOAPODS` macro definition which is"
          source.puts "// defined in the xcconfigs so it is available in"
          source.puts "// headers also when they are imported in the client"
          source.puts "// project."
          source.puts
          source.puts
          specs.each do |spec|
            spec_name = safe_spec_name(spec.name)
            source.puts "// #{spec.name}"
            source.puts "#define COCOAPODS_POD_AVAILABLE_#{spec_name}"
            if spec.version.semantic?
              source.puts "#define COCOAPODS_VERSION_MAJOR_#{spec_name} #{spec.version.major}"
              source.puts "#define COCOAPODS_VERSION_MINOR_#{spec_name} #{spec.version.minor}"
              source.puts "#define COCOAPODS_VERSION_PATCH_#{spec_name} #{spec.version.patch}"
            else
              source.puts "// This library does not follow semantic-versioning,"
              source.puts "// so we were not able to define version macros."
              source.puts "// Please contact the author."
              source.puts "// Version: #{spec.version}."
            end
            source.puts
          end
        end
      end

      #-----------------------------------------------------------------------#

      private

      # !@group Private Helpers

      def safe_spec_name(spec_name)
        spec_name.gsub(/[^\w]/,'_')
      end

      #-----------------------------------------------------------------------#

    end
  end
end
