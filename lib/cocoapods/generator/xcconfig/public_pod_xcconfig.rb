module Pod
  module Generator

    #
    class PublicPodXCConfig < XCConfig

      # Generates and saves the xcconfig to the given path.
      #
      # @param  [Pathname] path
      #         the path where the prefix header should be stored.
      #
      # @note   The public xcconfig file for a spec target is completely
      #         namespaced to prevent configuration value collision with other
      #         spec configurations.
      #
      # @return [void]
      #
      def save_as(path)
        generate.save_as(path, target.xcconfig_prefix)
      end

      # Generates the xcconfig for the target.
      #
      # @note   The xcconfig file for a public spec target includes the
      #         standard podspec defined values including libraries,
      #         frameworks, weak frameworks and xcconfig overrides.
      #
      # @return [Xcodeproj::Config]
      #
      def generate
        @xcconfig = Xcodeproj::Config.new
        target.spec_consumers.each do |consumer|
          add_spec_build_settings_to_xcconfig(consumer, @xcconfig)
        end
        @xcconfig
      end

      #-----------------------------------------------------------------------#

    end
  end
end
