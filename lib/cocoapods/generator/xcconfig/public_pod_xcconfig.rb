module Pod
  module Generator

    # Generates the public xcconfigs for the pod targets.
    #
    # The public xcconfig file for a Pod is completely namespaced to prevent
    # configuration value collision with the build settings of other Pods. This
    # xcconfig includes the standard podspec defined values including
    # libraries, frameworks, weak frameworks and xcconfig overrides.
    #
    class PublicPodXCConfig < XCConfig

      # Generates and saves the xcconfig to the given path.
      #
      # @param  [Pathname] path
      #         the path where the prefix header should be stored.
      #
      # @return [void]
      #
      def save_as(path)
        generate.save_as(path, target.xcconfig_prefix)
      end

      # Generates the xcconfig for the target.
      #
      # @return [Xcodeproj::Config]
      #
      def generate
        @xcconfig = Xcodeproj::Config.new
        target.file_accessors.each do |file_accessor|
          add_spec_build_settings_to_xcconfig(file_accessor.spec_consumer, @xcconfig)
          file_accessor.framework_bundles.each do |framework_bundle|
            add_framework_build_settings(framework_bundle, @xcconfig)
          end
        end
        @xcconfig
      end

      #-----------------------------------------------------------------------#

    end
  end
end
