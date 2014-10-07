require 'active_support/core_ext/string/strip'

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
      # @return [Hash{String => LocalPod}] the specifications installed for
      #         the target by build configuration name.
      #
      attr_reader :specs_by_configuration

      # @param  [Array<Specification>] pods @see pods
      #
      def initialize(specs_by_configuration)
        @specs_by_configuration = specs_by_configuration
      end

      # Generates and saves the file.
      #
      # @param  [Pathname] pathname
      #         The path where to save the generated file.
      #
      # @return [void]
      #
      def generate
        result = "\n#{notice}\n\n"
        common_specs = common_specs(specs_by_configuration)
        common_specs.each { |spec| result << spec_defines(spec) }

        specs_by_config = specs_scoped_by_configuration(common_specs, specs_by_configuration)
        specs_by_config.each do |config, specs|
          result << "// #{config} build configuration\n"
          result << "#ifdef #{config.gsub(/[^a-zA-Z0-9_]/, '_').upcase}\n\n"
          specs.each { |spec| result << spec_defines(spec, 1) }
          result << "#endif\n"
        end
        result
      end

      def save_as(path)
        path.open('w') { |header| header.write(generate) }
      end

      private

      # !@group Private Helpers
      #-----------------------------------------------------------------------#

      # @return [Array<Specification>] The list of the specifications present
      #         in all build configurations sorted by name.
      #
      # @param  [Hash{String => Array<Specification>}] specs_by_configuration
      #         The specs grouped by build configuration.
      #
      def common_specs(specs_by_configuration)
        result = specs_by_configuration.values.flatten.uniq
        specs_by_configuration.values.each do |configuration_specs|
          result = result & configuration_specs
        end
        result.sort_by(&:name)
      end

      # @return [Hash{String => Array<Specification>}] The list of the
      #         specifications not present in all build configurations sorted
      #         by name and grouped by build configuration name.
      #
      # @param  [Hash{String => Array<Specification>}] specs_by_configuration
      #         The specs grouped by build configuration.
      #
      def specs_scoped_by_configuration(common_specs, specs_by_configuration)
        result = {}
        specs_by_configuration.each do |configuration, all_specs|
          specs = all_specs.sort_by(&:name) - common_specs
          result[configuration] = specs unless specs.empty?
        end
        result
      end

      # @return The sanitized name of a specification to make it suitable to be
      #         used as part of an identifier of a define statement.
      #
      # @param  [String] spec_name
      #         The name of the spec.
      #
      def safe_spec_name(spec_name)
        spec_name.gsub(/[^\w]/, '_')
      end

      # @return [String]
      #
      def notice
        <<-DOC.strip_heredoc
          // To check if a library is compiled with CocoaPods you
          // can use the `COCOAPODS` macro definition which is
          // defined in the xcconfigs so it is available in
          // headers also when they are imported in the client
          // project.
        DOC
      end

      # @return [String]
      #
      def spec_defines(spec, indent_count = 0)
        spec_name = safe_spec_name(spec.name)
        result = "// #{spec.name}\n"
        result << "#define COCOAPODS_POD_AVAILABLE_#{spec_name}\n"
        if spec.version.semantic?
          result << semantic_version_defines(spec)
        else
          result << non_semantic_version_notice(spec)
        end
        result << "\n"
        indent(result, indent_count)
      end

      def indent(string, indent_count)
        indent = ' ' * (indent_count * 2)
        lines = string.lines.map do |line|
          if line == "\n"
            line
          else
            "#{indent}#{line}"
          end
        end
        lines.join
      end

      # @return [String]
      #
      def semantic_version_defines(spec)
        spec_name = safe_spec_name(spec.name)
        <<-DOC.strip_heredoc
          #define COCOAPODS_VERSION_MAJOR_#{spec_name} #{spec.version.major}
          #define COCOAPODS_VERSION_MINOR_#{spec_name} #{spec.version.minor}
          #define COCOAPODS_VERSION_PATCH_#{spec_name} #{spec.version.patch}
        DOC
      end

      # @return [String]
      #
      def non_semantic_version_notice(spec)
        <<-DOC.strip_heredoc
          // This library does not follow semantic-versioning,
          // so we were not able to define version macros.
          // Please contact the author.
          // Version: #{spec.version}.
        DOC
      end

      #-----------------------------------------------------------------------#
    end
  end
end
