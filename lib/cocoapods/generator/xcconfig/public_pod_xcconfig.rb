module Pod
  module Generator
    module XCConfig
      # Generates the public xcconfigs for the pod targets.
      #
      # The public xcconfig file for a Pod is completely namespaced to prevent
      # configuration value collision with the build settings of other Pods. This
      # xcconfig includes the standard podspec defined values including
      # libraries, frameworks, weak frameworks and xcconfig overrides.
      #
      class PublicPodXCConfig
        # @return [Target] the target represented by this xcconfig.
        #
        attr_reader :target

        # @param  [Target] target @see target
        #
        def initialize(target)
          @target = target
        end

        # @return [Xcodeproj::Config] The generated xcconfig.
        #
        attr_reader :xcconfig

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
            XCConfigHelper.add_spec_build_settings_to_xcconfig(file_accessor.spec_consumer, @xcconfig)
            file_accessor.vendored_frameworks.each do |vendored_framework|
              XCConfigHelper.add_framework_build_settings(vendored_framework, @xcconfig, target.sandbox.root)
            end
            file_accessor.vendored_libraries.each do |vendored_library|
              XCConfigHelper.add_library_build_settings(vendored_library, @xcconfig, target.sandbox.root)
            end
          end
          @xcconfig
        end

        #-----------------------------------------------------------------------#
      end
  end
end
end
